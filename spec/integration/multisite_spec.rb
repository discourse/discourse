# require 'rails_helper'
#
# describe 'multisite' do
#
#   class DBNameMiddleware
#     def initialize(app, config = {})
#       @app = app
#     end
#
#     def call(env)
#       # note current_db is already being ruined on boot cause its not multisite
#       [200, {}, [RailsMultisite::ConnectionManagement.current_hostname]]
#     end
#   end
#
#   let :session do
#     RailsMultisite::ConnectionManagement.config_filename = "spec/fixtures/multisite/two_dbs.yml"
#     RailsMultisite::ConnectionManagement.load_settings!
#
#     stack = ActionDispatch::MiddlewareStack.new
#     stack.use RailsMultisite::ConnectionManagement, RailsMultisite::DiscoursePatches.config
#     stack.use DBNameMiddleware
#
#     routes = ActionDispatch::Routing::RouteSet.new
#     stack.build(routes)
#   end
#
#   it "should always allow /srv/status through" do
#     headers = {
#       "HTTP_HOST" => "unknown.com",
#       "REQUEST_METHOD" => "GET",
#       "PATH_INFO" => "/srv/status",
#       "rack.input" => StringIO.new
#     }
#
#     code, _, body = session.call(headers)
#     expect(code).to eq(200)
#     expect(body.join).to eq("test.localhost")
#   end
#
#   it "should 404 on unknown routes" do
#     headers = {
#       "HTTP_HOST" => "unknown.com",
#       "REQUEST_METHOD" => "GET",
#       "PATH_INFO" => "/topics",
#       "rack.input" => StringIO.new
#     }
#
#     code, _ = session.call(headers)
#     expect(code).to eq(404)
#   end
#
#   it "should hit correct site elsewise" do
#
#     headers = {
#       "HTTP_HOST" => "test2.localhost",
#       "REQUEST_METHOD" => "GET",
#       "PATH_INFO" => "/topics",
#       "rack.input" => StringIO.new
#     }
#
#     code, _, body = session.call(headers)
#     expect(code).to eq(200)
#     expect(body.join).to eq("test2.localhost")
#   end
#
# end
