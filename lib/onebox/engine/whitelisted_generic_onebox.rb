require 'ipaddr'

module Onebox
  module Engine
    class WhitelistedGenericOnebox
      # overwrite the whitelist
      def self.===(other)
        if other.is_a?(URI)
          (
            begin
              IPAddr.new(other.hostname)
            rescue StandardError
              nil
            end
          )
            .nil?
        else
          true
        end
      end

      # ensure we're the last engine to be used
      def self.priority
        Float::INFINITY
      end

      private

      # overwrite to whitelist iframes
      def is_embedded?
        return false unless data[:html] && data[:height]
        if WhitelistedGenericOnebox.html_providers.include?(
           data[:provider_name]
         )
          return true
        end

        if data[:html]['iframe']
          fragment = Nokogiri::HTML.fragment(data[:html])
          if iframe = fragment.at_css('iframe')
            src = iframe['src']

            return src.present? &&
              SiteSetting.allowed_iframes.split('|').any? do |url|
                src.start_with?(url)
              end
          end
        end

        false
      end
    end
  end
end
