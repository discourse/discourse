# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class EntryPoint
      def inject_into(plugin)
        # Include random topics in the suggested list *only* if there are no related topics.
        plugin.register_modifier(
          :topic_view_suggested_topics_options,
        ) do |suggested_options, topic_view|
          related_topics = topic_view.related_topics
          include_random = !related_topics || related_topics.topics.length == 0
          suggested_options.merge(include_random: include_random)
        end

        # Query and serialize related topics.
        plugin.add_to_class(:topic_view, :related_topics) do
          if topic.private_message? || !SiteSetting.ai_embeddings_semantic_related_topics_enabled
            return nil
          end

          @related_topics ||=
            ::DiscourseAi::Embeddings::SemanticTopicQuery.new(@user).list_semantic_related_topics(
              topic,
            )
        end

        # define_method must be used (instead of add_to_class) to make sure
        # that method still works when plugin is disabled too
        TopicView.alias_method(:categories_old, :categories)
        TopicView.define_method(:categories) do
          @categories ||= [*categories_old, *related_topics&.categories].flatten.uniq.compact
        end

        %i[topic_view TopicViewPosts].each do |serializer|
          plugin.add_to_serializer(
            serializer,
            :related_topics,
            include_condition: -> { SiteSetting.ai_embeddings_semantic_related_topics_enabled },
          ) do
            if object.next_page.nil? && !object.topic.private_message?
              object.related_topics.topics.map do |t|
                SuggestedTopicSerializer.new(t, scope: scope, root: false)
              end
            end
          end
        end

        plugin.register_html_builder("server:topic-show-after-posts-crawler") do |controller|
          ::DiscourseAi::Embeddings::SemanticRelated.related_topics_for_crawler(controller)
        end

        # embeddings generation.
        callback =
          Proc.new do |target|
            if DiscourseAi::Embeddings.enabled? &&
                 (target.is_a?(Topic) || SiteSetting.ai_embeddings_per_post_enabled)
              Jobs.enqueue(
                :generate_embeddings,
                target_id: target.id,
                target_type: target.class.name,
              )
            end
          end

        plugin.on(:topic_created, &callback)
        plugin.on(:topic_edited, &callback)
        plugin.on(:post_created, &callback)
        plugin.on(:post_edited, &callback)

        plugin.add_api_key_scope(
          :discourse_ai,
          { search: { actions: %w[discourse_ai/embeddings/embeddings#search] } },
        )
      end
    end
  end
end
