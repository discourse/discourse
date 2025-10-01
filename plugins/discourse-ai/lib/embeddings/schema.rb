# frozen_string_literal: true

# We don't have AR objects for our embeddings, so this class
# acts as an intermediary between us and the DB.
# It lets us retrieve embeddings either symmetrically and asymmetrically,
# and also store them.

module DiscourseAi
  module Embeddings
    class Schema
      TOPICS_TABLE = "ai_topics_embeddings"
      POSTS_TABLE = "ai_posts_embeddings"
      RAG_DOCS_TABLE = "ai_document_fragments_embeddings"

      EMBEDDING_TARGETS = %w[topics posts document_fragments]
      EMBEDDING_TABLES = [TOPICS_TABLE, POSTS_TABLE, RAG_DOCS_TABLE]

      DEFAULT_HNSW_EF_SEARCH = 40

      MissingEmbeddingError = Class.new(StandardError)

      class << self
        def for(target_klass, vector_def: nil)
          vector_def =
            EmbeddingDefinition.find_by(
              id: SiteSetting.ai_embeddings_selected_model,
            ) if vector_def.nil?
          raise "Invalid embeddings selected model" if vector_def.nil?

          case target_klass&.name
          when "Topic"
            new(TOPICS_TABLE, "topic_id", vector_def)
          when "Post"
            new(POSTS_TABLE, "post_id", vector_def)
          when "RagDocumentFragment"
            new(RAG_DOCS_TABLE, "rag_document_fragment_id", vector_def)
          else
            raise ArgumentError, "Invalid target type for embeddings"
          end
        end

        def search_index_name(table, def_id)
          "ai_#{table}_embeddings_#{def_id}_1_search_bit"
        end

        def prepare_search_indexes(vector_def)
          EMBEDDING_TARGETS.each { |target| DB.exec <<~SQL }
              CREATE INDEX IF NOT EXISTS #{search_index_name(target, vector_def.id)} ON ai_#{target}_embeddings
              USING hnsw ((binary_quantize(embeddings)::bit(#{vector_def.dimensions})) bit_hamming_ops)
              WHERE model_id = #{vector_def.id} AND strategy_id = 1;
            SQL
        end

        def correctly_indexed?(vector_def)
          index_names = EMBEDDING_TARGETS.map { |t| search_index_name(t, vector_def.id) }
          indexdefs =
            DB.query_single(
              "SELECT indexdef FROM pg_indexes WHERE indexname IN (:names)",
              names: index_names,
            )

          return false if indexdefs.length < index_names.length

          indexdefs.all? do |defs|
            defs.include? "(binary_quantize(embeddings))::bit(#{vector_def.dimensions})"
          end
        end

        def remove_orphaned_data
          removed_defs_ids =
            DB.query_single(
              "SELECT DISTINCT(model_id) FROM #{TOPICS_TABLE} te LEFT JOIN embedding_definitions ed ON te.model_id = ed.id WHERE ed.id IS NULL",
            )

          EMBEDDING_TABLES.each do |t|
            DB.exec(
              "DELETE FROM #{t} WHERE model_id IN (:removed_defs)",
              removed_defs: removed_defs_ids,
            )
          end

          drop_index_statement =
            EMBEDDING_TARGETS
              .reduce([]) do |memo, et|
                removed_defs_ids.each do |rdi|
                  memo << "DROP INDEX IF EXISTS #{search_index_name(et, rdi)};"
                end

                memo
              end
              .join("\n")

          DB.exec(drop_index_statement)
        end
      end

      def initialize(table, target_column, vector_def)
        @table = table
        @target_column = target_column
        @vector_def = vector_def
      end

      attr_reader :table, :target_column, :vector_def

      def find_by_embedding(embedding)
        DB.query(
          <<~SQL,
          SELECT *
          FROM #{table}
          WHERE
            model_id = :vid AND strategy_id = :vsid
          ORDER BY
            embeddings::halfvec(#{dimensions}) #{pg_function} '[:query_embedding]'::halfvec(#{dimensions})
          LIMIT 1
        SQL
          query_embedding: embedding,
          vid: vector_def.id,
          vsid: vector_def.strategy_id,
        ).first
      end

      def find_by_target(target)
        DB.query(
          <<~SQL,
          SELECT *
          FROM #{table}
          WHERE
            model_id = :vid AND
            strategy_id = :vsid AND
            #{target_column} = :target_id
          LIMIT 1
        SQL
          target_id: target.id,
          vid: vector_def.id,
          vsid: vector_def.strategy_id,
        ).first
      end

      def asymmetric_similarity_search(embedding, limit:, offset:)
        before_query = hnsw_search_workaround(limit)

        builder = DB.build(<<~SQL)
          WITH candidates AS (
            SELECT
              #{target_column},
              embeddings::halfvec(#{dimensions}) AS embeddings
            FROM
              #{table}
            /*join*/
            /*where*/
            ORDER BY
              binary_quantize(embeddings)::bit(#{dimensions}) <~> binary_quantize('[:query_embedding]'::halfvec(#{dimensions}))
            LIMIT :candidates_limit
          )
          SELECT
            #{target_column},
            embeddings::halfvec(#{dimensions}) #{pg_function} '[:query_embedding]'::halfvec(#{dimensions}) AS distance
          FROM
            candidates
          ORDER BY
            embeddings::halfvec(#{dimensions}) #{pg_function} '[:query_embedding]'::halfvec(#{dimensions})
          LIMIT :limit
          OFFSET :offset;
        SQL

        builder.where(
          "model_id = :model_id AND strategy_id = :strategy_id",
          model_id: vector_def.id,
          strategy_id: vector_def.strategy_id,
        )

        yield(builder) if block_given?

        if table == RAG_DOCS_TABLE
          # A too low limit exacerbates the the recall loss of binary quantization
          candidates_limit = [limit * 2, 100].max
        else
          candidates_limit = limit * 2
        end

        ActiveRecord::Base.transaction do
          DB.exec(before_query) if before_query.present?
          builder.query(
            query_embedding: embedding,
            candidates_limit: candidates_limit,
            limit: limit,
            offset: offset,
          )
        end
      rescue PG::Error => e
        Rails.logger.error("Error #{e} querying embeddings for model #{vector_def.display_name}")
        raise MissingEmbeddingError
      end

      def symmetric_similarity_search(record, age_penalty: 0.0)
        limit = 200
        before_query = hnsw_search_workaround(limit)

        # For topics table, we can apply age penalty. For other tables, ignore the penalty.
        use_age_penalty = age_penalty > 0.0 && table == TOPICS_TABLE

        builder = DB.build(<<~SQL)
          WITH le_target AS (
            SELECT
              embeddings
            FROM
              #{table}
            WHERE
              model_id = :vid AND
              strategy_id = :vsid AND
              #{target_column} = :target_id
            LIMIT 1
          )
          SELECT #{target_column} FROM (
            SELECT
              #{target_column}, embeddings /*extra_columns*/
            FROM
              #{table}
            /*join*/
            /*extra_join*/
            /*where*/
            ORDER BY
              binary_quantize(embeddings)::bit(#{dimensions}) <~> (
                SELECT
                  binary_quantize(embeddings)::bit(#{dimensions})
                FROM
                  le_target
                LIMIT 1
              )
            LIMIT #{limit}
          ) AS widenet
          /*ordering*/
          LIMIT #{limit / 2};
        SQL

        builder.where("model_id = :vid AND strategy_id = :vsid")

        if use_age_penalty
          builder.sql_literal(
            extra_join: "INNER JOIN topics ON topics.id = #{table}.#{target_column}",
            extra_columns: ", topics.bumped_at",
            ordering: <<~SQL,
              ORDER BY
              (embeddings::halfvec(#{dimensions}) #{pg_function} (
                SELECT
                  embeddings::halfvec(#{dimensions})
                FROM
                  le_target
                LIMIT 1
              )) / POWER(EXTRACT(EPOCH FROM NOW() - bumped_at) / 86400 / :time_scale + 1, :age_penalty)
            SQL
          )
        else
          builder.sql_literal(ordering: <<~SQL)
            ORDER BY
            embeddings::halfvec(#{dimensions}) #{pg_function} (
              SELECT
                embeddings::halfvec(#{dimensions})
              FROM
                le_target
              LIMIT 1
            )
          SQL
        end

        yield(builder) if block_given?

        query_params = { vid: vector_def.id, vsid: vector_def.strategy_id, target_id: record.id }
        if use_age_penalty
          query_params[:age_penalty] = age_penalty
          query_params[:time_scale] = SiteSetting.ai_embeddings_semantic_related_age_time_scale
        end

        ActiveRecord::Base.transaction do
          DB.exec(before_query) if before_query.present?
          builder.query(query_params)
        end
      rescue PG::Error => e
        Rails.logger.error("Error #{e} querying embeddings for model #{vector_def.display_name}")
        raise MissingEmbeddingError
      end

      def store(record, embedding, digest)
        DB.exec(
          <<~SQL,
          INSERT INTO #{table} (#{target_column}, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
          VALUES (:target_id, :model_id, :model_version, :strategy_id, :strategy_version, :digest, '[:embeddings]', :now, :now)
          ON CONFLICT (model_id, strategy_id, #{target_column})
          DO UPDATE SET
            model_version = :model_version,
            strategy_version = :strategy_version,
            digest = :digest,
            embeddings = '[:embeddings]',
            updated_at = :now
          SQL
          target_id: record.id,
          model_id: vector_def.id,
          model_version: vector_def.version,
          strategy_id: vector_def.strategy_id,
          strategy_version: vector_def.strategy_version,
          digest: digest,
          embeddings: embedding,
          now: Time.zone.now,
        )
      end

      private

      def hnsw_search_workaround(limit)
        threshold = limit * 2

        return "" if threshold < DEFAULT_HNSW_EF_SEARCH
        "SET LOCAL hnsw.ef_search = #{threshold};"
      end

      delegate :dimensions, :pg_function, to: :vector_def
    end
  end
end
