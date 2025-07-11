# frozen_string_literal: true

module Jobs
  module DiscourseRssPolling
    class FixTopicEmbedAuthors < ::Jobs::Base
      sidekiq_options queue: "low"

      def mismatched_topic_embeds
        TopicEmbed.joins(post: :topic).where("posts.user_id != topics.user_id")
      end

      def execute(args)
        mismatched_topic_embeds.find_each do |topic_embed|
          post = topic_embed.post

          PostOwnerChanger.new(
            post_ids: [post.id],
            topic_id: post.topic_id,
            new_owner: post.user,
            acting_user: Discourse.system_user,
            skip_revision: true,
          ).change_owner!
        end
      end
    end
  end
end
