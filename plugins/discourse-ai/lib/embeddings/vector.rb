# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class Vector
      def self.instance
        vector_def = EmbeddingDefinition.find_by(id: SiteSetting.ai_embeddings_selected_model)
        raise "Invalid embeddings selected model" if vector_def.nil?

        new(vector_def)
      end

      def initialize(vector_definition)
        @vdef = vector_definition
      end

      delegate :tokenizer, to: :vdef

      MAX_CONCURRENT_EMBEDDINGS = 40

      def gen_bulk_reprensentations(relation)
        pool =
          Scheduler::ThreadPool.new(
            min_threads: 0,
            max_threads: MAX_CONCURRENT_EMBEDDINGS,
            idle_time: 30,
          )

        schema = DiscourseAi::Embeddings::Schema.for(relation.first.class, vector_def: @vdef)

        queued = 0
        results = Queue.new
        # map so we release the DB connection
        relation.map do |record|
          prepared_text = vdef.prepare_target_text(record)
          next if prepared_text.blank?

          new_digest = OpenSSL::Digest::SHA1.hexdigest(prepared_text)
          next if schema.find_by_target(record)&.digest == new_digest

          pool.post do
            results << { target: record, text: prepared_text, digest: new_digest }.merge(
              embedding: request_embedding!(prepared_text),
            )
          rescue StandardError => e
            results << e
          end
          queued += 1
        end

        errors = []
        while queued > 0
          result = results.pop
          if result.is_a?(StandardError)
            errors << result
          else
            schema.store(result[:target], result[:embedding], result[:digest]) if result.present?
          end
          queued -= 1
        end

        unexpected_errors = errors.reject { |error| expected_provider_error?(error) }
        if unexpected_errors.any?
          Discourse.warn_exception(
            unexpected_errors.first,
            message:
              "Discourse AI: Unexpected errors during bulk embedding generation: #{unexpected_errors.count}",
          )
        end
      ensure
        pool.shutdown
        pool.wait_for_termination(timeout: 30)
      end

      def generate_representation_from(target)
        text = vdef.prepare_target_text(target)
        return if text.blank?

        schema = DiscourseAi::Embeddings::Schema.for(target.class, vector_def: @vdef)

        new_digest = OpenSSL::Digest::SHA1.hexdigest(text)
        return if schema.find_by_target(target)&.digest == new_digest

        embeddings = request_embedding!(text)

        schema.store(target, embeddings, new_digest)
      end

      def vector_from(text, asymmetric = false)
        prepared_text = vdef.prepare_query_text(text, asymmetric: asymmetric)
        return if prepared_text.blank?

        request_embedding!(prepared_text)
      end

      attr_reader :vdef

      private

      def request_embedding!(text)
        ProviderHealth.request!(vdef) { vdef.inference_client.perform!(text) }
      end

      def expected_provider_error?(error)
        error.is_a?(ProviderPausedError) ||
          error.is_a?(DiscourseAi::Inference::EmbeddingInferenceError)
      end
    end
  end
end
