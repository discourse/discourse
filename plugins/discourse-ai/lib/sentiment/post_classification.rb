# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class PostClassification
      include Constants

      def self.enabled_for?(classification_type)
        case classification_type.to_s
        when "sentiment"
          SiteSetting.ai_sentiment_enabled
        when "emotion"
          SiteSetting.ai_sentiment_emotion_enabled
        else
          false
        end
      end

      def self.any_enabled?
        enabled_for?(:sentiment) || enabled_for?(:emotion)
      end

      def self.backfill_query(from_post_id: nil, max_age_days: nil)
        available_classifier_names = active_classifier_names
        return Post.none if available_classifier_names.blank?

        queries =
          available_classifier_names.map do |classifier_name|
            quoted_classifier_name = ActiveRecord::Base.connection.quote(classifier_name)

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
                  AND crs.model_used = #{quoted_classifier_name}
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

        Post.from(Arel.sql("(#{unioned_queries}) as posts")).includes(:sentiment_classifications)
      end

      def self.active_classifier_names
        new.classifiers.map { |classifier| classifier[:model_name] }
      end

      def self.active_model_name_for(classification_type)
        classification_type = classification_type.to_s

        case strategy_for(classification_type)
        when Constants::AGENT_STRATEGY
          return classification_type == "sentiment" ? SENTIMENT_AGENT_MODEL : EMOTION_AGENT_MODEL
        when Constants::DECISION_MODEL_STRATEGY
          return(
            classification_type == "sentiment" ? SENTIMENT_DECISION_MODEL : EMOTION_DECISION_MODEL
          )
        end

        configured_model_name_for(classification_type) ||
          default_model_name_for(classification_type)
      end

      def self.configured_model_name_for(classification_type)
        configs = DiscourseAi::Sentiment::SentimentSiteSettingJsonSchema.values
        return if configs.blank?

        classification_type = classification_type.to_s

        explicitly_typed_config =
          configs.find do |config|
            config.respond_to?(:classification_type) &&
              config.classification_type.to_s == classification_type
          end
        return explicitly_typed_config.model_name if explicitly_typed_config.present?

        default_config =
          configs.find { |config| config.model_name == default_model_name_for(classification_type) }
        return default_config.model_name if default_config.present?

        configs
          .find { |config| classification_type_for(config) == classification_type }
          &.model_name || untyped_custom_model_name(configs, classification_type)
      end

      def self.untyped_custom_model_name(configs, classification_type)
        return if classification_type != "sentiment"

        untyped_configs = configs.select { |config| classification_type_for(config).blank? }
        untyped_configs.one? ? untyped_configs.first.model_name : nil
      end

      def self.default_model_name_for(classification_type)
        if classification_type.to_s == "sentiment"
          Constants::SENTIMENT_MODEL
        else
          Constants::EMOTION_MODEL
        end
      end

      def self.classification_type_for(config)
        if config.respond_to?(:classification_type) && config.classification_type.present?
          return config.classification_type.to_s
        end

        return "sentiment" if config.model_name == Constants::SENTIMENT_MODEL
        return "emotion" if config.model_name == Constants::EMOTION_MODEL

        nil
      end

      def self.strategy_for(classification_type)
        if classification_type.to_s == "sentiment"
          SiteSetting.ai_sentiment_sentiment_classification_strategy
        else
          SiteSetting.ai_sentiment_emotion_classification_strategy
        end
      end

      def self.agent_configuration_for(classification_type)
        agent_id = SiteSetting.public_send("ai_sentiment_#{classification_type}_agent")
        ai_agent = AiAgent.find_by_id_from_cache(agent_id)
        return { agent: nil, model: nil } if ai_agent.blank?

        model_id = ai_agent.default_llm_id || SiteSetting.ai_default_llm_model
        model = model_id.present? ? LlmModel.find_by(id: model_id) : LlmModel.last
        { agent: ai_agent, model: model }
      end

      def self.decision_model_for(classification_type)
        model_id = SiteSetting.public_send("ai_sentiment_#{classification_type}_decision_model")
        DecisionModel.find_by(id: model_id) if model_id.present?
      end

      def self.classifier_summary_for(classification_type)
        backend = strategy_for(classification_type)
        case backend
        when Constants::AGENT_STRATEGY
          configuration = agent_configuration_for(classification_type)
          {
            backend: backend,
            ready: configuration.values.all?(&:present?),
            agent_ids: [configuration[:agent]&.id].compact,
            llm_models: [configuration[:model]].compact,
          }
        when Constants::DECISION_MODEL_STRATEGY
          model = decision_model_for(classification_type)
          {
            backend: backend,
            ready: model.present?,
            decision_model: model && { id: model.id, display_name: model.display_name },
          }
        else
          model_name = active_model_name_for(classification_type)
          config =
            SentimentSiteSettingJsonSchema.values.find { |value| value.model_name == model_name }
          {
            backend: backend,
            ready: config.present? && config.endpoint.present?,
            classification_model: {
              model_name: model_name,
            },
          }
        end
      end

      MAX_INPUT_WORDS = 3000
      CONCURRENT_CLASSFICATIONS = 40
      CONCURRENT_AGENT_CLASSIFICATIONS = 5

      def bulk_classify!(relation)
        available_classifiers = classifiers
        return if available_classifiers.blank?

        max_threads =
          (
            if available_classifiers.any? { |c| c[:provider] != :classification_model }
              CONCURRENT_AGENT_CLASSIFICATIONS
            else
              CONCURRENT_CLASSFICATIONS
            end
          )

        pool = Scheduler::ThreadPool.new(min_threads: 0, max_threads: max_threads, idle_time: 30)

        results = Queue.new
        queued = 0

        relation.each do |record|
          text = prepare_text(record)
          next if text.blank?

          already_classified = record.sentiment_classifications.map(&:model_used)
          missing_classifiers =
            available_classifiers.reject { |ac| already_classified.include?(ac[:model_name]) }

          missing_classifiers.each do |classifier|
            pool.post do
              result = { target: record, classifier: classifier, text: text }
              begin
                result[:classification] = request_with(classifier, record, text)
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
          elsif result[:classification].present?
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
        if pool
          pool.shutdown
          pool.wait_for_termination(timeout: 30)
        end
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
          classifiers_for_target.each_with_object({}) do |cft, memo|
            classification = request_with(cft, target, to_classify)
            memo[cft[:model_name]] = classification if classification.present?
          end

        store_classification(target, results) if results.present?
      end

      def classifiers
        hugging_face_classifiers + agent_classifiers + decision_classifiers
      end

      def has_classifiers?
        classifiers.present?
      end

      private

      def hugging_face_classifiers
        if %i[sentiment emotion].none? { |type|
             self.class.enabled_for?(type) && dedicated_strategy_for?(type)
           }
          return []
        end

        configs = DiscourseAi::Sentiment::SentimentSiteSettingJsonSchema.values
        untyped_sentiment_model = self.class.untyped_custom_model_name(configs, "sentiment")

        configs.filter_map do |config|
          classification_type = classification_type_for(config)
          effective_type =
            classification_type.presence ||
              ("sentiment" if config.model_name == untyped_sentiment_model)
          next unless self.class.enabled_for?(effective_type.presence || :sentiment)
          next if effective_type.present? && !dedicated_strategy_for?(effective_type)

          api_endpoint = config.endpoint

          if api_endpoint.present? && api_endpoint.start_with?("srv://")
            service = DiscourseAi::Utils::DnsSrv.lookup(api_endpoint.delete_prefix("srv://"))
            api_endpoint = "https://#{service.target}:#{service.port}"
          end

          {
            classification_type: classification_type,
            model_name: config.model_name,
            client:
              DiscourseAi::Inference::HuggingFaceTextEmbeddings.new(api_endpoint, config.api_key),
            provider: :classification_model,
          }
        end
      end

      def agent_classifiers
        %i[sentiment emotion].filter_map { |type| agent_classifier(type) }
      end

      def agent_classifier(classification_type)
        return unless self.class.enabled_for?(classification_type)
        return if self.class.strategy_for(classification_type) != Constants::AGENT_STRATEGY

        configuration = self.class.agent_configuration_for(classification_type)
        ai_agent, model = configuration.values_at(:agent, :model)
        return if ai_agent.blank? || model.blank?

        {
          classification_type: classification_type.to_s,
          model_name: self.class.active_model_name_for(classification_type),
          agent: ai_agent.class_instance.new,
          user: ai_agent.user || Discourse.system_user,
          model: model,
          provider: :agent,
        }
      end

      def decision_classifiers
        %i[sentiment emotion].filter_map do |type|
          next unless self.class.enabled_for?(type)
          next if self.class.strategy_for(type) != Constants::DECISION_MODEL_STRATEGY

          model = self.class.decision_model_for(type)
          next if model.blank?

          {
            classification_type: type.to_s,
            model_name: self.class.active_model_name_for(type),
            model: model,
            provider: :decision_model,
          }
        end
      end

      def classification_type_for(config)
        self.class.classification_type_for(config)
      end

      def dedicated_strategy_for?(classification_type)
        self.class.strategy_for(classification_type) == Constants::CLASSIFICATION_MODEL_STRATEGY
      end

      def prepare_text(target)
        if target.post_number == 1
          "#{target.topic.title}\n#{target.raw}"
        else
          target.raw
        end
      end

      def prepare_classifier_input(classifier, content)
        if classifier[:provider] != :classification_model
          return content.truncate_words(MAX_INPUT_WORDS, omission: "")
        end

        DiscourseAi::Tokenizer::BertTokenizer.truncate(
          content,
          512,
          strict: SiteSetting.ai_strict_token_counting,
        )
      end

      def request_with(classifier, target, content)
        content = prepare_classifier_input(classifier, content)
        return request_with_agent(classifier, target, content) if classifier[:provider] == :agent

        if classifier[:provider] == :decision_model
          return request_with_decision_model(classifier, content)
        end

        result = classifier[:client].classify_by_sentiment!(content)

        transform_result(result)
      end

      def transform_result(result)
        hash_result = {}
        result.each { |r| hash_result[r[:label]] = r[:score] }
        hash_result
      end

      def request_with_agent(classifier, target, content)
        context =
          DiscourseAi::Agents::BotContext.new(
            post: target,
            messages: [{ type: :user, content: content }],
            user: classifier[:user],
            skip_show_thinking: true,
            feature_name: "sentiment",
          )

        bot =
          DiscourseAi::Agents::Bot.as(
            classifier[:user],
            agent: classifier[:agent],
            model: classifier[:model],
          )

        structured_output = nil
        raw_result = +""
        bot.reply(context) do |partial, _, type|
          if type == :structured_output
            structured_output = partial
          else
            raw_result << partial.to_s
          end
        end

        transform_agent_result(
          structured_output,
          raw_result,
          labels_for(classifier[:classification_type]),
        )
      end

      def request_with_decision_model(classifier, content)
        type = classifier[:classification_type]
        result =
          classifier[:model].decide(
            content,
            questions: [ClassificationQuestion.for(type)],
            user: Discourse.system_user,
            feature_name: type,
          )
        answer = result[type]
        answer.probabilities unless answer.refusal?
      end

      def transform_agent_result(structured_output, raw_result, labels)
        parsed_result = parse_raw_agent_result(raw_result)

        result =
          labels.index_with do |label|
            value =
              structured_output&.read_buffered_property(label.to_sym) || parsed_result[label] ||
                parsed_result[label.to_sym] || 0

            value.to_f.clamp(0.0, 1.0)
          end

        return nil if result.values.all?(&:zero?)
        result
      end

      def parse_raw_agent_result(raw_result)
        return {} if raw_result.blank?

        JSON.parse(raw_result)
      rescue JSON::ParserError
        {}
      end

      def labels_for(classification_type)
        classification_type.to_s == "sentiment" ? %w[negative neutral positive] : Emotions::LIST
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
