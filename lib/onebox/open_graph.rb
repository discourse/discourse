# frozen_string_literal: true

module Onebox
  class OpenGraph

    attr_reader :data

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

    def method_missing(attr, *args, &block)
      value = get(attr, *args)

      return nil if Onebox::Helpers::blank?(value)

      method_name = attr.to_s
      if method_name.end_with?(*integer_suffixes)
        value.to_i
      elsif method_name.end_with?(*url_suffixes)
        result = Onebox::Helpers.normalize_url_for_output(value)
        result unless Onebox::Helpers::blank?(result)
      else
        value
      end
    end

    def get(attr, length = nil, sanitize = true)
      return nil if Onebox::Helpers::blank?(data)

      value = data[attr]

      return nil if Onebox::Helpers::blank?(value)

      value = html_entities.decode(value)
      value = Sanitize.fragment(value) if sanitize
      value.strip!
      value = Onebox::Helpers.truncate(value, length) unless length.nil?

      value
    end

    private

    def integer_suffixes
      ['width', 'height']
    end

    def url_suffixes
      ['url', 'image', 'video']
    end

    def html_entities
      @html_entities ||= HTMLEntities.new
    end

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
