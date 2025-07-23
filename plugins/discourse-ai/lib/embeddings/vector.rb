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

      def gen_bulk_reprensentations(relation)
        http_pool_size = 100
        pool =
          Concurrent::CachedThreadPool.new(
            min_threads: 0,
            max_threads: http_pool_size,
            idletime: 30,
          )

        schema = DiscourseAi::Embeddings::Schema.for(relation.first.class, vector_def: @vdef)

        embedding_gen = vdef.inference_client
        promised_embeddings =
          relation
            .map do |record|
              prepared_text = vdef.prepare_target_text(record)
              next if prepared_text.blank?

              new_digest = OpenSSL::Digest::SHA1.hexdigest(prepared_text)
              next if schema.find_by_target(record)&.digest == new_digest

              Concurrent::Promises
                .fulfilled_future({ target: record, text: prepared_text, digest: new_digest }, pool)
                .then_on(pool) do |w_prepared_text|
                  w_prepared_text.merge(embedding: embedding_gen.perform!(w_prepared_text[:text]))
                end
                .rescue { nil } # We log the error during #perform. Skip failed embeddings.
            end
            .compact

        Concurrent::Promises
          .zip(*promised_embeddings)
          .value!
          .each { |e| schema.store(e[:target], e[:embedding], e[:digest]) if e.present? }
      ensure
        pool.shutdown
        pool.wait_for_termination
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
