# frozen_string_literal: true

module Jobs
  class RebakeGithubPrPosts < ::Jobs::Base
    sidekiq_options queue: "low"

    def execute(args)
      url = args[:pr_url]
      return if url.blank?

      # invalidate & refresh the onebox cache for this PR URL
      Oneboxer.preview(url, invalidate_oneboxes: true)

      rebake_posts(url)
      rebake_chat_messages(url) if SiteSetting.chat_enabled
    end

    private

    def rebake_posts(url)
      post_ids = TopicLink.where(url:).or(TopicLink.where("url LIKE ?", "#{url}%")).select(:post_id)

      Post
        .where(id: post_ids)
        .where("cooked LIKE ?", "%githubpullrequest%#{url}%")
        .find_each { |post| post.rebake!(priority: :low, skip_publish_rebaked_changes: true) }
    end

    def rebake_chat_messages(url)
      message_ids =
        ::Chat::MessageLink
          .where(url:)
          .or(::Chat::MessageLink.where("url LIKE ?", "#{url}%"))
          .select(:chat_message_id)

      ::Chat::Message
        .where(id: message_ids)
        .where("cooked LIKE ?", "%githubpullrequest%#{url}%")
        .find_each { |message| message.rebake!(priority: :low, skip_notifications: true) }
    end
  end
end
