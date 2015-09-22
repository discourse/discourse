if Rails.env.production?
  Logster.store.ignore = [
    # honestly, Rails should not be logging this, its real noisy
    /^ActionController::RoutingError \(No route matches/,

    /^PG::Error: ERROR:\s+duplicate key/,

    /^ActionController::UnknownFormat/,

    /^AbstractController::ActionNotFound/,

    # alihack is really annoying, nothing really we can do about this
    # (795: unexpected token at 'alihack<%eval request("alihack.com")%> '):
    /^ActionDispatch::ParamsParser::ParseError/,

    # ignore any empty JS errors that contain blanks or zeros for line and column fields
    #
    # Line:
    # Column:
    #
    /(?m).*?Line: (?:\D|0).*?Column: (?:\D|0)/,

    # also empty JS errors
    /^Script error\..*Line: 0/m,

    # CSRF errors are not providing enough data
    # suppress unconditionally for now
    /^Can't verify CSRF token authenticity$/,

    # 404s can be dealt with elsewise
    /^ActiveRecord::RecordNotFound /,

    # bad asset requested, no need to log
    /^ActionController::BadRequest /
  ]
end

# middleware that logs errors sits before multisite
# we need to establish a connection so redis connection is good
# and db connection is good
Logster.config.current_context = lambda{|env,&blk|
  begin
    if Rails.configuration.multisite
      request = Rack::Request.new(env)
      ActiveRecord::Base.connection_handler.clear_active_connections!
      RailsMultisite::ConnectionManagement.establish_connection(:host => request['__ws'] || request.host)
    end
    blk.call
  ensure
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end
}

# TODO logster should be able to do this automatically
Logster.config.subdirectory = "#{GlobalSetting.relative_url_root}/logs"

Logster.config.application_version = Discourse.git_version
