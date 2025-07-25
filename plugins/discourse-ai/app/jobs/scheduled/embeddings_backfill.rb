# frozen_string_literal: true

module Jobs
  class EmbeddingsBackfill < ::Jobs::Scheduled
    every 5.minutes
    sidekiq_options queue: "low"
    cluster_concurrency 1

    def execute(args)
      return unless DiscourseAi::Embeddings.enabled?

      limit = SiteSetting.ai_embeddings_backfill_batch_size

      if limit > 50_000
        limit = 50_000
        Rails.logger.warn(
          "Limiting backfill batch size to 50,000 to avoid OOM errors, reduce ai_embeddings_backfill_batch_size to avoid this warning",
        )
      end

      production_vector = DiscourseAi::Embeddings::Vector.instance

      if SiteSetting.ai_embeddings_backfill_model.present? &&
           SiteSetting.ai_embeddings_backfill_model != SiteSetting.ai_embeddings_selected_model
        backfill_vector =
          DiscourseAi::Embeddings::Vector.new(
            EmbeddingDefinition.find_by(id: SiteSetting.ai_embeddings_backfill_model),
          )
      end

      topic_work_list = []
      topic_work_list << production_vector
      topic_work_list << backfill_vector if backfill_vector

      topic_work_list.each do |vector|
        rebaked = 0
        table_name = DiscourseAi::Embeddings::Schema::TOPICS_TABLE
        vector_def = vector.vdef

        topics =
          Topic
            .joins(
              "LEFT JOIN #{table_name} ON #{table_name}.topic_id = topics.id AND #{table_name}.model_id = #{vector_def.id}",
            )
            .where(archetype: Archetype.default)
            .where(deleted_at: nil)
            .order("topics.bumped_at DESC")

        rebaked += populate_topic_embeddings(vector, topics.limit(limit - rebaked))

        next if rebaked >= limit

        # Then, we'll try to backfill embeddings for topics that have outdated
        # embeddings, be it model or strategy version
        relation = topics.where(<<~SQL).limit(limit - rebaked)
            #{table_name}.model_version < #{vector_def.version}
            OR
            #{table_name}.strategy_version < #{vector_def.strategy_version}
          SQL

        rebaked += populate_topic_embeddings(vector, relation, force: true)

        next if rebaked >= limit

        # Finally, we'll try to backfill embeddings for topics that have outdated
        # embeddings due to edits or new replies. Here we only do 10% of the limit
        relation =
          topics
            .where("#{table_name}.updated_at < ?", 6.hours.ago)
            .where("#{table_name}.updated_at < topics.updated_at")
            .limit((limit - rebaked) / 10)

        populate_topic_embeddings(vector, relation, force: true)

        next unless SiteSetting.ai_embeddings_per_post_enabled

        # Now for posts
        table_name = DiscourseAi::Embeddings::Schema::POSTS_TABLE
        posts_batch_size = 1000

        posts =
          Post
            .joins(
              "LEFT JOIN #{table_name} ON #{table_name}.post_id = posts.id AND #{table_name}.model_id = #{vector_def.id}",
            )
            .where(deleted_at: nil)
            .where(post_type: Post.types[:regular])

        # First, we'll try to backfill embeddings for posts that have none
        posts
          .where("#{table_name}.post_id IS NULL")
          .limit(limit - rebaked)
          .pluck(:id)
          .each_slice(posts_batch_size) do |batch|
            vector.gen_bulk_reprensentations(Post.where(id: batch))
            rebaked += batch.length
          end

        next if rebaked >= limit

        # Then, we'll try to backfill embeddings for posts that have outdated
        # embeddings, be it model or strategy version
        posts
          .where(<<~SQL)
            #{table_name}.model_version < #{vector_def.version}
            OR
            #{table_name}.strategy_version < #{vector_def.strategy_version}
          SQL
          .limit(limit - rebaked)
          .pluck(:id)
          .each_slice(posts_batch_size) do |batch|
            vector.gen_bulk_reprensentations(Post.where(id: batch))
            rebaked += batch.length
          end

        next if rebaked >= limit

        # Finally, we'll try to backfill embeddings for posts that have outdated
        # embeddings due to edits. Here we only do 10% of the limit
        posts
          .where("#{table_name}.updated_at < ?", 7.days.ago)
          .order("random()")
          .limit((limit - rebaked) / 10)
          .pluck(:id)
          .each_slice(posts_batch_size) do |batch|
            vector.gen_bulk_reprensentations(Post.where(id: batch))
            rebaked += batch.length
          end
      end
    end

    private

    def populate_topic_embeddings(vector, topics, force: false)
      done = 0

      topics =
        topics.where("#{DiscourseAi::Embeddings::Schema::TOPICS_TABLE}.topic_id IS NULL") if !force

      ids = topics.pluck("topics.id")
      batch_size = 1000

      ids.each_slice(batch_size) do |batch|
        vector.gen_bulk_reprensentations(Topic.where(id: batch).order("topics.bumped_at DESC"))
        done += batch.length
      end

      done
    end
  end
end
