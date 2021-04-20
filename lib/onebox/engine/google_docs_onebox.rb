# frozen_string_literal: true

module Onebox
  module Engine
    class GoogleDocsOnebox
      include Engine
      include LayoutSupport

      SUPPORTED_ENDPOINTS = %w(spreadsheets document forms presentation)
      SHORT_TYPES = {
        spreadsheets: :sheets,
        document: :docs,
        presentation: :slides,
        forms: :forms,
      }

      matches_regexp(/^(https?:)?\/\/(docs\.google\.com)\/(?<endpoint>(#{SUPPORTED_ENDPOINTS.join('|')}))\/d\/((?<key>[\w-]*)).+$/)
      always_https

      private

      def data
        short_type = SHORT_TYPES[match[:endpoint].to_sym]

        {
          link: link,
          title: og_data[:title] || "Google #{short_type.to_s.capitalize}",
          description: Onebox::Helpers.truncate(og_data[:description], 250) || "This #{short_type.to_s.chop.capitalize} is private",
          type: short_type
        }
      end

      def match
        @match ||= @url.match(@@matcher)
      end

      def og_data
        return @og_data if defined?(@og_data)

        response = Onebox::Helpers.fetch_response(url, redirect_limit: 10) rescue nil
        html = Nokogiri::HTML(response)
        @og_data = {}

        html.css('meta').each do |m|
          if m.attribute('property')&.to_s&.match(/^og:/i)
            m_content = m.attribute('content').to_s.strip
            m_property = m.attribute('property').to_s.gsub('og:', '')
            @og_data[m_property.to_sym] = m_content
          end
        end

        @og_data
      end
    end
  end
end
