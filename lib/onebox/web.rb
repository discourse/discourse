require 'haml'
require 'yaml'
require 'sinatra/base'
require 'sinatra/reloader'
require 'onebox'
require 'onebox/web_helpers'
require 'multi_json'

module Onebox
  class Web < Sinatra::Base
    set :root, File.expand_path(File.dirname(__FILE__) + "/../../web")
    set :public_folder, Proc.new { "#{root}/assets" }
    set :views, Proc.new { "#{root}/views" }
    configure :development do
      enable :logging
    end

    helpers WebHelpers

    get '/' do
      haml :index, format: :html5
    end

    get '/onebox' do
      content_type :json
      result = {
          url: params[:url],
          engine: Onebox::Matcher.new(params[:url]).oneboxed.to_s
      }
      onebox = Onebox.preview(params[:url])
      result.merge!(onebox: onebox.to_s, placeholder: onebox.placeholder_html)
      MultiJson.dump(result)
    end
  end
end
