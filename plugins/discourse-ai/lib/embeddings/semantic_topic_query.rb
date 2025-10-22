# frozen_string_literal: true

class DiscourseAi::Embeddings::SemanticTopicQuery < TopicQuery
  def list_semantic_related_topics(topic)
    query_opts = {
      skip_ordering: true,
      per_page: SiteSetting.ai_embeddings_semantic_related_topics,
      unordered: true,
    }

    if !SiteSetting.ai_embeddings_semantic_related_include_closed_topics
      query_opts[:status] = "open"
    end

    list =
      create_list(:semantic_related, query_opts) do |topics|
        candidate_ids = DiscourseAi::Embeddings::SemanticRelated.new.related_topic_ids_for(topic)

        list = topics.where.not(id: topic.id).where(id: candidate_ids)

        list = DiscoursePluginRegistry.apply_modifier(:semantic_related_topics_query, list)

        # array_position forces the order of the topics to be preserved
        list = list.order("array_position(ARRAY#{candidate_ids}, topics.id)")
        list = remove_muted(list, @user, query_opts)
      end
  end
end
