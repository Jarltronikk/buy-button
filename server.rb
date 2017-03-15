require "sinatra"
require 'json'
require "bunny"
require 'haml'
require 'securerandom'
require 'thread'
$base_uri=nil
rabbitConn = Bunny.new(ENV["RABBITMQ"])
rabbitConn.start
channel=rabbitConn.create_channel
$registryExchange=channel.topic("registry")
$orderExchange=channel.topic("orders")
def notify_product
  if not $base_uri.nil?
    $registryExchange.publish('{"key":"buy","priority":0,"uri-template":"'+$base_uri+'/buy-button?product={product}"}', :routing_key => "action.product.registration")
  end
end
queue = channel.queue("", :exclusive => true, :durable=>false)
queue.bind($registryExchange, :routing_key=>"product.registration")
queue.subscribe(:manual_ack => true, :block => false) do |delivery_info, properties, body|
  begin
    notify_product
  rescue
    #TODO
  end
  channel.ack(delivery_info.delivery_tag)
end
error do
  @e = request.env['sinatra_error']
  puts @e
  "500 server error".to_json
end

get '/buy-button' do
  haml :buy_button ,:locals=>{:uri=>params['product']}
end

get '/buy-button/buy-button-component' do
  haml :buy_button_component
end

get '/buy-button/register-hack' do
  $base_uri=request.base_url
  notify_product
  "OK"
end


post '/buy-button/order' do
  request.body.rewind
  payload = JSON.parse request.body.read

  id=SecureRandom.uuid.to_s
  response={}
  unblock = Thread::Queue.new
  order_queue = channel.queue("", :exclusive => true, :durable=>false)
  order_queue.bind($orderExchange, :routing_key=>"created.order")
  subscriber = order_queue.subscribe() do |delivery_info, properties, body|
    message=JSON.parse body
    if(message["id"]==id)
      puts id
      response[:uri]=message["uri"]
      unblock.enq true
    end
  end
  $orderExchange.publish('{"id":"'+id+'","items":[{"product":"'+payload['product']+'","Quantity":1}]}', :routing_key =>"create.order")
  unblock.deq
  subscriber.cancel
  response.to_json
end