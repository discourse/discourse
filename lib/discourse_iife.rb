class DiscourseIIFE
  def initialize(options = {}, &block)
  end

  def self.instance
    @instance ||= new
  end

  def self.call(input)
    instance.call(input)
  end

  # Add a IIFE around our javascript
  def call(input)
    path = input[:environment].context_class.new(input).pathname.to_s
    data = input[:data]

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

    return data if path =~ /discourse-loader/

    "(function () {\n\nvar $ = window.jQuery;\n// IIFE Wrapped Content Begins:\n\n#{data}\n\n// IIFE Wrapped Content Ends\n\n })(this);"
  end

end
