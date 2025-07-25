# frozen_string_literal: true
module DiscourseAi
  module AiBot
    module SharedAiConversationsHelper
      # keeping it here for caching
      def self.share_asset_url(asset_name)
        if !%w[share.css highlight.js].include?(asset_name)
          raise StandardError, "unknown asset type #{asset_name}"
        end

        @urls ||= {}
        url = @urls[asset_name]
        return url if url

        path = asset_name
        path = "highlight.min.js" if asset_name == "highlight.js"

        content = File.read(DiscourseAi.public_asset_path("ai-share/#{path}"))
        sha1 = Digest::SHA1.hexdigest(content)

        url = "/discourse-ai/ai-bot/shared-ai-conversations/asset/#{sha1}/#{asset_name}"

        @urls[asset_name] = GlobalPath.cdn_path(url)
      end

      def share_asset_url(asset_name)
        DiscourseAi::AiBot::SharedAiConversationsHelper.share_asset_url(asset_name)
      end
    end
  end
end
