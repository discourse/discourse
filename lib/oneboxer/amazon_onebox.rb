require_dependency 'oneboxer/handlebars_onebox'

module Oneboxer
  class AmazonOnebox < HandlebarsOnebox

    matcher /^https?:\/\/(?:www\.)?amazon.(com|ca)\/.*$/
    favicon 'amazon.png'

    def template
      template_path("simple_onebox")
    end

    # Use the mobile version of the site
    def translate_url
      # If we're already mobile don't translate the url
      return @url if @url =~ /https?:\/\/www\.amazon\.com\/gp\/aw\/d\//

      m = @url.match(/(?:d|g)p\/(?:product\/)?(?<id>[^\/]+)(?:\/|$)/mi)
      return "http://www.amazon.com/gp/aw/d/" + URI::encode(m[:id]) if m.present?
      @url
    end

    def parse(data)
      html_doc = Nokogiri::HTML(data)

      result = {}
      result[:title] = html_doc.at("h1")
      result[:title] = result[:title].inner_text.strip if result[:title].present?

      image = html_doc.at("#main-image")
      result[:image] = image['src'] if image

      result[:by_info] = html_doc.at("#by-line")
      result[:by_info] = BaseOnebox.remove_whitespace(BaseOnebox.replace_tags_with_spaces(result[:by_info].inner_html)) if result[:by_info].present?

      summary = html_doc.at("#description-and-details-content")
      result[:text] = summary.inner_html if summary.present?

      result
    end

  end
end
