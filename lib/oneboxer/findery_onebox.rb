require_dependency 'oneboxer/handlebars_onebox'

module Oneboxer
  class FinderyOnebox < HandlebarsOnebox

    matcher /^https?:\/\/(www\.)?findery\.com\/.*\/notes\/.*$/
    favicon 'findery.png'

    def template
      template_path("simple_onebox")
    end

    def parse(data)
      html_doc = Nokogiri::HTML(data)

      result = {}
      result[:title] = html_doc.at(".note-heading a")
      result[:title] = result[:title].inner_html if result[:title].present?

      image = html_doc.at(".note-media-object img")
      result[:image] = image['src'] if image

      result[:by_info] = html_doc.at(".created-byline .username")
      result[:by_info] = result[:by_info].inner_html if result[:by_info].present?

      note_text = html_doc.at(".note-message")
      result[:text] = note_text.inner_html if note_text.present?

      result
    end

  end
end
