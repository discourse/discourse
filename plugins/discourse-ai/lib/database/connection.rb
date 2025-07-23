# frozen_string_literal: true

module ::DiscourseAi
  module Database
    class Connection
      def self.db
        pg_conn = PG.connect(SiteSetting.ai_embeddings_pg_connection_string)
        MiniSql::Connection.get(pg_conn)
      end
    end
  end
end
