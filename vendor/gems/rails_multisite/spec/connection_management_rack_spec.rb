require 'spec_helper'
require 'rails_multisite'
require 'rack/test'

describe RailsMultisite::ConnectionManagement do
  include Rack::Test::Methods

  def app

    RailsMultisite::ConnectionManagement.config_filename = 'spec/fixtures/two_dbs.yml'
    RailsMultisite::ConnectionManagement.load_settings!

    @app ||= Rack::Builder.new {
      use RailsMultisite::ConnectionManagement
      map '/html' do
        run lambda { |env| [200, {'Content-Type' => 'text/html'}, "<html><BODY><h1>Hi</h1></BODY>\n \t</html>"] }
      end
    }.to_app
  end

  after do
    RailsMultisite::ConnectionManagement.clear_settings!
  end

  describe 'with a valid request' do

    before do
    end

    it 'returns 200 for valid site' do
      get 'http://second.localhost/html'
      last_response.should be_ok
    end

    it 'returns 200 for valid main site' do
      get 'http://default.localhost/html'
      last_response.should be_ok
    end

    it 'returns 404 for invalid site' do
      get '/html'
      last_response.should be_not_found
    end
  end

end

