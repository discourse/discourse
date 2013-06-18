class DiscourseIIFE < Sprockets::Processor

  # Add a IIFE around our javascript
  def evaluate(context, locals)

    path = context.pathname.to_s

    # Only discourse or admin paths
    return data unless (path =~ /\/javascripts\/discourse/ || path =~ /\/javascripts\/admin/ || path =~ /\/test\/javascripts/)

    # Ignore the js helper
    return data if (path =~ /test\_helper\.js/)

    # Ignore translations
    return data if (path =~ /\/translations/)

    # We don't add IIFEs to handlebars
    return data if path =~ /\.handlebars/
    return data if path =~ /\.shbrs/
    return data if path =~ /\.hbrs/

    "(function () {\n\nvar $ = window.jQuery;\n\n#{data}\n\n})(this);"
  end

end