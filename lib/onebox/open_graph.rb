# frozen_string_literal: true

module Onebox
  class OpenGraph < Normalizer

    def initialize(doc)
      @data = extract(doc)
    end

    def title
      get(:title, 80)
    end

    def title_attr
      !title.nil? ? "title='#{title}'" : ""
    end

    def secure_image_url
      secure_url = URI(get(:image))
      secure_url.scheme = 'https'
      secure_url.to_s
    end

    private

    def extract(doc)
      return {} if Onebox::Helpers::blank?(doc)

      data = {}

      doc.css('meta').each do |m|
        if (m["property"] && m["property"][/^(?:og|article|product):(.+)$/i]) || (m["name"] && m["name"][/^(?:og|article|product):(.+)$/i])
          value = (m["content"] || m["value"]).to_s
          data[$1.tr('-:', '_').to_sym] ||= value unless Onebox::Helpers::blank?(value)
        end
      end

      # Attempt to retrieve the title from the meta tag
      title_element = doc.at_css('title')
      if title_element && title_element.text
        data[:title] ||= title_element.text unless Onebox::Helpers.blank?(title_element.text)
      end

      data
    end
  end
end
