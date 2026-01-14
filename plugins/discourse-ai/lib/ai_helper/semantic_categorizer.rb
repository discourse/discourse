# frozen_string_literal: true
module DiscourseAi
  module AiHelper
    class SemanticCategorizer
      def initialize(user, opts)
        @user = user
        @text = opts[:text]
        @vector = DiscourseAi::Embeddings::Vector.instance
        @schema = DiscourseAi::Embeddings::Schema.for(Topic)
        @topic_id = opts[:topic_id]
      end

      def categories
        return [] if @text.blank? && @topic_id.nil?
        return [] if !DiscourseAi::Embeddings.enabled?

        candidates = nearest_neighbors
        return [] if candidates.empty?

        candidate_ids = candidates.map(&:first)

        ::Topic
          .joins(:category)
          .where(id: candidate_ids)
          .where("categories.id IN (?)", Category.topic_create_allowed(@user.guardian).pluck(:id))
          .order("array_position(ARRAY#{candidate_ids}, topics.id)")
          .pluck(
            "categories.id",
            "categories.name",
            "categories.slug",
            "categories.color",
            "categories.topic_count",
          )
          .map
          .with_index do |(id, name, slug, color, topic_count), index|
            {
              id: id,
              name: name,
              slug: slug,
              color: color,
              topicCount: topic_count,
              score: candidates[index].last,
            }
          end
          .map do |c|
            # Note: <#> returns the negative inner product since Postgres only supports ASC order index scans on operators
            c[:score] = (c[:score] + 1).abs if @vector.vdef.pg_function = "<#>"

            c[:score] = 1 / (c[:score] + 1) # inverse of the distance
            c
          end
          .group_by { |c| c[:name] }
          .map { |name, scores| scores.first.merge(score: scores.sum { |s| s[:score] }) }
          .sort_by { |c| -c[:score] }
          .take(5)
      end

      def tags
        return [] if @text.blank? && @topic_id.nil?
        return [] if !DiscourseAi::Embeddings.enabled?

        candidates = nearest_neighbors(limit: 100)
        return [] if candidates.empty?

        candidate_ids = candidates.map(&:first)

        count_column = Tag.topic_count_column(@user.guardian) # Determine the count column

        ::Topic
          .joins(:topic_tags, :tags)
          .where(id: candidate_ids)
          .where("tags.id IN (?)", DiscourseTagging.visible_tags(@user.guardian).pluck(:id))
          .group("topics.id")
          .order("array_position(ARRAY#{candidate_ids}, topics.id)")
          .pluck("array_agg(tags.name)")
          .map(&:uniq)
          .map
          .with_index { |tag_list, index| { tags: tag_list, score: candidates[index].last } }
          .flat_map { |c| c[:tags].map { |t| { name: t, score: c[:score] } } }
          .map do |c|
            # Note: <#> returns the negative inner product since Postgres only supports ASC order index scans on operators
            c[:score] = (c[:score] + 1).abs if @vector.vdef.pg_function = "<#>"

            c[:score] = 1 / (c[:score] + 1) # inverse of the distance
            c
          end
          .group_by { |c| c[:name] }
          .map { |name, scores| { name: name, score: scores.sum { |s| s[:score] } } }
          .sort_by { |c| -c[:score] }
          .take(7)
          .then do |tags|
            models = Tag.where(name: tags.map { _1[:name] }).index_by(&:name)
            tags.map do |tag|
              tag[:id] = models.dig(tag[:name])&.id
              tag[:count] = models.dig(tag[:name])&.public_send(count_column) || 0
              tag
            end
          end
      end

      private

      def nearest_neighbors(limit: 50)
        if @topic_id
          target = Topic.find_by(id: @topic_id)
          embeddings = @schema.find_by_target(target)&.embeddings

          if embeddings.blank?
            @text =
              DiscourseAi::Summarization::Strategies::TopicSummary
                .new(target)
                .targets_data
                .pluck(:text)
            raw_vector = @vector.vector_from(@text)
          else
            raw_vector = JSON.parse(embeddings)
          end
        else
          raw_vector = @vector.vector_from(@text)
        end

        muted_category_ids = nil
        if @user.present?
          muted_category_ids =
            CategoryUser.where(
              user: @user,
              notification_level: CategoryUser.notification_levels[:muted],
            ).pluck(:category_id)
        end

        @schema
          .asymmetric_similarity_search(raw_vector, limit: limit, offset: 0) do |builder|
            builder.join("topics t on t.id = topic_id")
            unless muted_category_ids.empty?
              builder.where(<<~SQL, exclude_category_ids: muted_category_ids.map(&:to_i))
                t.category_id NOT IN (:exclude_category_ids) AND
                t.category_id NOT IN (SELECT categories.id FROM categories WHERE categories.parent_category_id IN (:exclude_category_ids))
              SQL
            end
          end
          .map { |r| [r.topic_id, r.distance] }
      end
    end
  end
end
