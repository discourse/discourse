
server 'discourse.edgeryders.eu', user: 'discourse', roles: [:web, :app, :db], primary: true

set :puma_bind, %w(tcp://0.0.0.0:9292 unix:///home/discourse/production/current/tmp/sockets/puma.sock)
