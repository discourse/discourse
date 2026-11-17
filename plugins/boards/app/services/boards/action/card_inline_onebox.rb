# frozen_string_literal: true

module Boards
  module Action
    class CardInlineOnebox < Service::ActionBase
      option :title

      def call
        url = exact_url
        return if url.blank?

        onebox = InlineOneboxer.lookup(url, invalidate: true)&.with_indifferent_access
        return if onebox&.dig(:title).blank?

        onebox.to_h.deep_stringify_keys
      rescue StandardError => error
        Rails.logger.warn("Boards: failed to inline onebox card title: #{error.message}")
        nil
      end

      private

      def exact_url
        value = title.to_s.strip
        return if value.blank? || value.match?(/\s/)

        uri = URI.parse(value)
        return if uri.scheme&.downcase != "https" || uri.host.blank?

        value
      rescue URI::InvalidURIError
        nil
      end
    end
  end
end
