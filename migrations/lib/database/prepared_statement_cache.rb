# frozen_string_literal: true

require "lru_redux"

module Migrations::Database
  class PreparedStatementCache < LruRedux::Cache
    class PreparedStatementHash < Hash
      def shift
        result = super
        if (stmt = result[1])
          stmt.close
        end
        result
      end

      def clear
        each_value(&:close)
        super
      end
    end

    def initialize(*args)
      super
      @data = PreparedStatementHash.new
    end
  end
end
