# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostHelper
      def create_workflow_post(exec_ctx, config, item_index, author_parameter: "author_username")
        topic = ::Topic.find(config["topic_id"])
        author = exec_ctx.actor_from_parameter(author_parameter, item_index)
        author.guardian.ensure_can_see!(topic)

        if topic.closed? || topic.archived?
          raise_node_error!(
            I18n.t("discourse_workflows.errors.create_post.topic_closed_or_archived"),
          )
        end

        post_args = {
          topic_id: topic.id,
          raw: config["raw"],
          reply_to_post_number: config["reply_to_post_number"].presence,
          skip_workflows: true,
        }.compact

        PostCreator.new(author, post_args).create!
      end

      def workflow_post_data(post, guardian:, include_raw: true, include_cooked: false)
        topic = post.topic
        category = topic&.category
        data = {
          id: post.id,
          topic_id: post.topic_id,
          topic_title: topic&.title,
          topic_slug: topic&.slug,
          post_number: post.post_number,
          post_url: post.url,
          username: post.user&.username,
          user_id: post.user_id,
          created_at: post.created_at&.utc&.iso8601,
          updated_at: post.updated_at&.utc&.iso8601,
          excerpt: post.excerpt(300, strip_links: true, text_entities: true),
          like_count: post.like_count,
          reply_count: post.reply_count,
          score: post.score,
          category_id: topic&.category_id,
          category_name: category&.name,
          tags: topic_tags(topic, guardian),
        }

        data[:raw] = post.raw if include_raw
        data[:cooked] = post.cooked if include_cooked
        data
      end

      def topic_tags(topic, guardian)
        return [] if topic.blank? || !SiteSetting.tagging_enabled

        topic.tags.visible(guardian).pluck(:name)
      end
    end
  end
end
