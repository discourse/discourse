# frozen_string_literal: true

module Onebox
  module Engine
    class GooglePlayAppOnebox
      include Engine
      include LayoutSupport
      include HTML

      DEFAULTS = { MAX_DESCRIPTION_CHARS: 500 }.freeze

      matches_regexp(%r{^https?://play\.(?:(?:\w)+\.)?(google)\.com(?:/)?/store/apps/})
      always_https

      private

      def data
        price =
          begin
            raw.css("meta[itemprop=price]").first["content"]
          rescue StandardError
            "Free"
          end
        {
          link: link,
          title:
            raw.css("meta[property='og:title']").first["content"].gsub(
              " - Apps on Google Play",
              "",
            ),
          image:
            ::Onebox::Helpers.normalize_url_for_output(
              raw.css("meta[property='og:image']").first["content"],
            ),
          description:
            raw.css("meta[name=description]").first["content"][
              0..DEFAULTS[:MAX_DESCRIPTION_CHARS]
            ].chop + "...",
          price: price == "0" ? "Free" : price,
        }
      end
    end
  end
end
