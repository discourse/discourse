module MessageBus::Rack; end

class MessageBus::Rack::Diagnostics
  def initialize(app, config = {})
    @app = app
  end

  def js_asset(name)
    return generate_script_tag(name) unless MessageBus.cache_assets
    @@asset_cache ||= {}
    @@asset_cache[name] ||= generate_script_tag(name)
    @@asset_cache[name]
  end

  def  generate_script_tag(name)
    "<script src='/message-bus/_diagnostics/assets/#{name}?#{file_hash(name)}' type='text/javascript'></script>"
  end

  def file_hash(asset)
    require 'digest/sha1'
    Digest::SHA1.hexdigest(asset_contents(asset))
  end

  def asset_contents(asset)
    File.open(asset_path(asset)).read
  end

  def asset_path(asset)
    File.expand_path("../../../../assets/#{asset}", __FILE__)
  end

  def index
    html = <<HTML
<!DOCTYPE html>
<html>
  <head>
  </head>
  <body>
    <div id="app"></div>
    #{js_asset "jquery-1.8.2.js"}
    #{js_asset "handlebars.js"}
    #{js_asset "ember.js"}
    #{js_asset "message-bus.js"}
    #{js_asset "application.handlebars"}
    #{js_asset "index.handlebars"}
    #{js_asset "application.js"}
  </body>
</html>
HTML
    return [200, {"content-type" => "text/html;"}, [html]]
  end

  def translate_handlebars(name, content)
    "Ember.TEMPLATES['#{name}'] = Ember.Handlebars.compile(#{indent(content).inspect});"
  end

  # from ember-rails
  def indent(string)
    string.gsub(/$(.)/m, "\\1  ").strip
  end

  def call(env)

    return @app.call(env) unless env['PATH_INFO'].start_with? '/message-bus/_diagnostics'

    route = env['PATH_INFO'].split('/message-bus/_diagnostics')[1]

    if MessageBus.is_admin_lookup.nil? || !MessageBus.is_admin_lookup.call(env)
      return [403, {}, ['not allowed']]
    end

    return index unless route

    if route == '/discover'
      user_id =  MessageBus.user_id_lookup.call(env)
      MessageBus.publish('/_diagnostics/discover', user_id: user_id)
      return [200, {}, ['ok']]
    end

    if route =~ /^\/hup\//
      hostname, pid = route.split('/hup/')[1].split('/')
      MessageBus.publish('/_diagnostics/hup', {hostname: hostname, pid: pid.to_i})
      return [200, {}, ['ok']]
    end

    asset = route.split('/assets/')[1]
    if asset && !asset !~ /\//
      content = asset_contents(asset)
      split = asset.split('.')
      if split[1] == 'handlebars'
        content = translate_handlebars(split[0],content)
      end
      return [200, {'content-type' => 'text/javascript;'}, [content]]
    end

    return [404, {}, ['not found']]
  end
end
