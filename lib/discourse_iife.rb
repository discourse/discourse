class DiscourseIIFE < Sprockets::Processor

  # Add a IIFE around our javascript
  def evaluate(context, locals)

    path = context.pathname.to_s

    # Only discourse or admin paths
    return data unless (path =~ /\/javascripts\/discourse/ || path =~ /\/javascripts\/admin/ || path =~ /\/test\/javascripts/)

    # Ignore the js helpers
    return data if (path =~ /test\_helper\.js/)
    return data if (path =~ /javascripts\/helpers\//)

    # Ignore ES6 files
    return data if (path =~ /\.es6/)

    # Ignore translations
    return data if (path =~ /\/translations/)

    # We don't add IIFEs to handlebars
    return data if path =~ /\.handlebars/
    return data if path =~ /\.shbrs/
    return data if path =~ /\.hbrs/
    return data if path =~ /\.hbs/

    res = "(function () {\n\nvar $ = window.jQuery;\n// IIFE Wrapped Content Begins:\n\n#{data}\n\n// IIFE Wrapped Content Ends\n\n })(this);"

    # Include JS code for JSHint
    unless Rails.env.production?
      req_path = path.sub(Rails.root.to_s, '')
                     .sub("/app/assets/javascripts", "")
                     .sub("/test/javascripts", "")
      res << "\nwindow.__jshintSrc = window.__jshintSrc || {}; window.__jshintSrc['/assets#{req_path}'] = #{data.to_json};\n"
    end

    res
  end

end
