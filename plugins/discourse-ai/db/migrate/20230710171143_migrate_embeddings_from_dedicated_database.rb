# frozen_string_literal: true

class MigrateEmbeddingsFromDedicatedDatabase < ActiveRecord::Migration[7.0]
  def up
    return unless SiteSetting.ai_embeddings_enabled
    return if SiteSetting.ai_embeddings_pg_connection_string.blank?

    truncation = DiscourseAi::Embeddings::Strategies::Truncation.new

    vector_reps =
      [
        DiscourseAi::Embeddings::VectorRepresentations::AllMpnetBaseV2,
        DiscourseAi::Embeddings::VectorRepresentations::TextEmbeddingAda002,
      ].map { |k| k.new(truncation) }

    vector_reps.each do |vector_rep|
      new_table_name = DiscourseAi::Embeddings::Schema::TOPICS_TABLE
      old_table_name = "topic_embeddings_#{vector_rep.name.underscore}"

      begin
        row_count =
          DiscourseAi::Database::Connection
            .db
            .query_single("SELECT COUNT(*) FROM #{old_table_name}")
            .first

        if row_count > 0
          puts "Migrating #{row_count} embeddings from #{old_table_name} to #{new_table_name}"

          last_topic_id = 0

          loop do
            batch = DiscourseAi::Database::Connection.db.query(<<-SQL)
                SELECT topic_id, embedding
                FROM #{old_table_name}
                WHERE topic_id > #{last_topic_id}
                ORDER BY topic_id ASC
                LIMIT 50
              SQL
            break if batch.empty?

            DB.exec(<<-SQL)
                INSERT INTO #{new_table_name} (topic_id, model_version, strategy_version, digest, embeddings, created_at, updated_at)
                VALUES #{batch.map { |r| "(#{r.topic_id}, 0, 0, '', '#{r.embedding}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)" }.join(", ")}
                ON CONFLICT (topic_id)
                DO NOTHING
              SQL

            last_topic_id = batch.last.topic_id
          end
        end
      rescue PG::Error => e
        Rails.logger.error(
          "Error #{e} migrating embeddings from #{old_table_name} to #{new_table_name}",
        )
      end
    end
  end

  def down
    # no-op
  end
end
