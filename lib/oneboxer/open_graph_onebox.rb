require_dependency 'oneboxer/handlebars_onebox'

module Oneboxer
  class OpenGraphOnebox < HandlebarsOnebox

    def template
      template_path('simple_onebox')
    end

    def onebox
      # We expect to have the options we need already
      return nil unless @opts.present?

      # A site is supposed to supply all the basic og attributes, but some don't (like deviant art)
      # If it just has image and no title, embed it as an image.
      return BaseOnebox.image_html(@opts['image'], nil, @url) if @opts['image'].present? and @opts['title'].blank?

      @opts['title'] ||= @opts['description']
      return nil if @opts['title'].blank?

      @opts[:original_url] = @url
      @opts[:text] = @opts['description']
      @opts[:unsafe] = true

      begin
        parsed = URI.parse(@url)
        @opts[:host] = parsed.host.split('.').last(2).join('.')
      rescue URI::InvalidURIError
        # In case there is a problem with the URL, we just won't set the host
      end

      Mustache.render(File.read(template), @opts)
    end

  end
end
