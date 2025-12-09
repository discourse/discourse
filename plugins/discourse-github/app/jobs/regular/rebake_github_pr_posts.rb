# frozen_string_literal: true

module Jobs
  class RebakeGithubPrPosts < ::Jobs::Base
    sidekiq_options queue: "low"

    def execute(args)
      pr_url = args[:pr_url]
      return if pr_url.blank?

      rebake_posts(pr_url)
      rebake_chat_messages(pr_url) if SiteSetting.chat_enabled
    end

    private

    def rebake_posts(pr_url)
      post_ids =
        TopicLink
          .where(url: pr_url)
          .or(TopicLink.where("url LIKE ?", "#{pr_url}%"))
          .select(:post_id)

      Post
        .where(id: post_ids)
        .find_each do |post|
          next unless has_github_pr_onebox?(post.cooked, pr_url)
          post.rebake!(invalidate_oneboxes: true, priority: :low)
        end
    end

    def rebake_chat_messages(pr_url)
      message_ids =
        ::Chat::MessageLink
          .where(url: pr_url)
          .or(::Chat::MessageLink.where("url LIKE ?", "#{pr_url}%"))
          .select(:chat_message_id)

      ::Chat::Message
        .where(id: message_ids)
        .find_each do |message|
          next unless has_github_pr_onebox?(message.cooked, pr_url)
          message.rebake!(invalidate_oneboxes: true, priority: :low)
        end
    end

    def has_github_pr_onebox?(cooked, pr_url)
      # quick & dirty check to avoid doing unnecessary rebakes
      # note: we use "githubpullrequest" instead of "onebox" to avoid matching inline oneboxes
      cooked.present? && cooked.include?("githubpullrequest") && cooked.include?(pr_url)
    end
  end
end
