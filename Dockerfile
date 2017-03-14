from ruby:2.1-onbuild
run bundler install
EXPOSE 80
CMD bundle exec thin start -p  80 -e production