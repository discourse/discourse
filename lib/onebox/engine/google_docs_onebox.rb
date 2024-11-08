# frozen_string_literal: true

module Onebox
  module Engine
    class GoogleDocsOnebox
      include Engine
      include StandardEmbed
      include LayoutSupport

      SUPPORTED_ENDPOINTS = %w[spreadsheets document forms presentation].freeze
      SHORT_TYPES = {
        spreadsheets: :sheets,
        document: :docs,
        presentation: :slides,
        forms: :forms,
      }.freeze

      matches_regexp(
        %r{^(https?:)?//(docs\.google\.com)/(?<endpoint>(#{SUPPORTED_ENDPOINTS.join("|")}))/d/((?<key>[\w-]*)).+$},
      )
      always_https

      private

      def data
        og_data = get_opengraph
        short_type = SHORT_TYPES[match[:endpoint].to_sym]

        description =
          if og_data.description.blank?
            "This #{short_type.to_s.chop.capitalize} is private"
          else
            Onebox::Helpers.truncate(og_data.description, 250)
          end

        {
          link: link,
          title: og_data.title || "Google #{short_type.to_s.capitalize}",
          description: description,
          type: short_type,
        }
      end

      def match
        @match ||= @url.match(@@matcher)
      end
    end
  end
end
