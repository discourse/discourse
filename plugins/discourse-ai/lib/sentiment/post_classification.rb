# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class PostClassification
      def self.backfill_query(from_post_id: nil, max_age_days: nil)
        available_classifier_names =
          DiscourseAi::Sentiment::SentimentSiteSettingJsonSchema.values.map { _1.model_name }

        queries =
          available_classifier_names.map do |classifier_name|
            base_query =
              Post
                .includes(:sentiment_classifications)
                .joins("INNER JOIN topics ON topics.id = posts.topic_id")
                .where(post_type: Post.types[:regular])
                .where.not(topics: { archetype: Archetype.private_message })
                .where(posts: { deleted_at: nil })
                .where(topics: { deleted_at: nil })
                .joins(<<~SQL)
                LEFT JOIN classification_results crs
                  ON crs.target_id = posts.id
                  AND crs.target_type = 'Post'
                  AND crs.classification_type = 'sentiment'
                  AND crs.model_used = '#{classifier_name}'
              SQL
                .where("crs.id IS NULL")

            base_query =
              base_query.where("posts.id >= ?", from_post_id.to_i) if from_post_id.present?

            if max_age_days.present?
              base_query =
                base_query.where(
                  "posts.created_at > current_date - INTERVAL '#{max_age_days.to_i} DAY'",
                )
            end

            base_query
          end

        unioned_queries = queries.map(&:to_sql).join(" UNION ")

        Post.from(Arel.sql("(#{unioned_queries}) as posts"))
      end

      CONCURRENT_CLASSFICATIONS = 40

      def bulk_classify!(relation)
        pool =
          Scheduler::ThreadPool.new(
            min_threads: 0,
            max_threads: CONCURRENT_CLASSFICATIONS,
            idle_time: 30,
          )

        available_classifiers = classifiers
        return if available_classifiers.blank?

        results = Queue.new
        queued = 0

        relation.each do |record|
          text = prepare_text(record)
          next if text.blank?

          already_classified = record.sentiment_classifications.pluck(&:model_used)
          missing_classifiers =
            available_classifiers.reject { |ac| already_classified.include?(ac[:model_name]) }

          missing_classifiers.each do |classifier|
            pool.post do
              result = { target: record, classifier: classifier, text: text }
              begin
                result[:classification] = request_with(classifier[:client], text)
              rescue StandardError => e
                result[:error] = e
              end
              results << result
            end
            queued += 1
          end
        end

        errors = []

        while queued > 0
          result = results.pop
          if result[:error]
            errors << result
          else
            store_classification(
              result[:target],
              [[result[:classifier][:model_name], result[:classification]]],
            )
          end
          queued -= 1
        end

        if errors.any?
          example_posts = errors.map { |e| e[:target].id }.take(5).join(", ")
          Discourse.warn_exception(
            errors[0][:error],
            message:
              "Discourse AI: Errors during bulk classification: Failed to classify #{errors.count} posts (example ids: #{example_posts})",
          )
        end
      ensure
        pool.shutdown
        pool.wait_for_termination(timeout: 30)
      end

      def classify!(target)
        return if target.blank?
        available_classifiers = classifiers
        return if available_classifiers.blank?

        to_classify = prepare_text(target)
        return if to_classify.blank?

        already_classified = target.sentiment_classifications.map(&:model_used)
        classifiers_for_target =
          available_classifiers.reject { |ac| already_classified.include?(ac[:model_name]) }

        results =
          classifiers_for_target.reduce({}) do |memo, cft|
            memo[cft[:model_name]] = request_with(cft[:client], to_classify)
            memo
          end

        store_classification(target, results)
      end

      def classifiers
        DiscourseAi::Sentiment::SentimentSiteSettingJsonSchema.values.map do |config|
          api_endpoint = config.endpoint

          if api_endpoint.present? && api_endpoint.start_with?("srv://")
            service = DiscourseAi::Utils::DnsSrv.lookup(api_endpoint.delete_prefix("srv://"))
            api_endpoint = "https://#{service.target}:#{service.port}"
          end

          {
            model_name: config.model_name,
            client:
              DiscourseAi::Inference::HuggingFaceTextEmbeddings.new(api_endpoint, config.api_key),
          }
        end
      end

      def has_classifiers?
        classifiers.present?
      end

      private

      def prepare_text(target)
        content =
          if target.post_number == 1
            "#{target.topic.title}\n#{target.raw}"
          else
            target.raw
          end

        DiscourseAi::Tokenizer::BertTokenizer.truncate(
          content,
          512,
          strict: SiteSetting.ai_strict_token_counting,
        )
      end

      def request_with(client, content)
        result = client.classify_by_sentiment!(content)

        transform_result(result)
      end

      def transform_result(result)
        hash_result = {}
        result.each { |r| hash_result[r[:label]] = r[:score] }
        hash_result
      end

      def store_classification(target, classification)
        attrs =
          classification.map do |model_name, classifications|
            {
              model_used: model_name,
              target_id: target.id,
              target_type: target.class.sti_name,
              classification_type: :sentiment,
              classification: classifications,
              updated_at: DateTime.now,
              created_at: DateTime.now,
            }
          end

        ClassificationResult.upsert_all(
          attrs,
          unique_by: %i[target_id target_type model_used],
          update_only: %i[classification],
        )
      end
    end
  end
end
