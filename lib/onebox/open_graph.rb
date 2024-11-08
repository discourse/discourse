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
      secure_url.scheme = "https"
      secure_url.to_s
    end

    private

    COLLECTIONS = %i[article_section article_section_color article_tag].freeze

    def extract(doc)
      return {} if doc.blank?

      data = {}

      doc
        .css("meta")
        .each do |m|
          if (m["property"] && m["property"][/\A(?:og|article|product):(.+)\z/i]) ||
               (m["name"] && m["name"][/\A(?:og|article|product):(.+)\z/i])
            value = (m["content"] || m["value"]).to_s
            next if value.blank?
            key = $1.tr("-:", "_").to_sym
            data[key] ||= value
            if key.in?(COLLECTIONS)
              collection_name = "#{key}s".to_sym
              data[collection_name] ||= []
              data[collection_name] << value
            end
          end
        end

      # Attempt to retrieve the title from the meta tag
      title_element = doc.at_css("title")
      data[:title] ||= title_element.text if title_element && title_element.text.present?

      data
    end
  end
end
