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

        embedding_gen = vdef.inference_client

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
              embedding: embedding_gen.perform!(prepared_text),
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

        if errors.any?
          Discourse.warn_exception(
            errors[0],
            message:
              "Discourse AI: Errors during bulk classification: Failed to generate embeddings on #{errors.count} posts",
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

        embeddings = vdef.inference_client.perform!(text)

        schema.store(target, embeddings, new_digest)
      end

      def vector_from(text, asymetric: false)
        prepared_text = vdef.prepare_query_text(text, asymetric: asymetric)
        return if prepared_text.blank?

        vdef.inference_client.perform!(prepared_text)
      end

      attr_reader :vdef
    end
  end
end
