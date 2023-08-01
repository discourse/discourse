# frozen_string_literal: true

module Onebox
  class Normalizer
    attr_reader :data

    def get(attr, *args)
      value = data[attr]
      return if value.blank?
      return value.map { |v| sanitize_value(v, *args) } if value.is_a?(Array)
      sanitize_value(value, *args)
    end

    def method_missing(attr, *args, &block)
      value = get(attr, *args)

      return nil if Onebox::Helpers.blank?(value)

      method_name = attr.to_s
      if method_name.end_with?(*integer_suffixes)
        value.to_i
      elsif method_name.end_with?(*url_suffixes)
        result = Onebox::Helpers.normalize_url_for_output(value)
        result unless Onebox::Helpers.blank?(result)
      else
        value
      end
    end

    private

    def integer_suffixes
      %w[width height]
    end

    def url_suffixes
      %w[url image video]
    end

    def html_entities
      @html_entities ||= HTMLEntities.new
    end

    def sanitize_value(value, length = nil, sanitize = true)
      value = html_entities.decode(value)
      value = Sanitize.fragment(value) if sanitize
      value.strip!
      value = Onebox::Helpers.truncate(value, length) if length
      value
    end
  end
end
