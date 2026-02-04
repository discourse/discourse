# frozen_string_literal: true

module Migrations::Converters::Phpbb3
  module SqlTransformer
    NAMED_PARAM_REGEX = /:([a-z_][a-z0-9_]*)/i

    def query(sql, params = {})
      transformed_sql, ordered_params = transform_sql(sql, params)
      @source_db.query(transformed_sql, *ordered_params)
    end

    def count(sql, params = {})
      transformed_sql, ordered_params = transform_sql(sql, params)
      @source_db.count(transformed_sql, *ordered_params)
    end

    private

    def transform_sql(sql, params)
      result = sql.dup
      result = replace_prefix(result)

      ordered_params = []
      param_index = 0

      result =
        result.gsub(NAMED_PARAM_REGEX) do
          name = Regexp.last_match(1).to_sym
          raise ArgumentError, "Missing parameter: #{name}" unless params.key?(name)

          ordered_params << params[name]
          param_index += 1
          postgres? ? "$#{param_index}" : "?"
        end

      [result, ordered_params]
    end

    def replace_prefix(sql)
      configured_prefix = settings.dig(:phpbb, :table_prefix) || "phpbb_"
      return sql if configured_prefix == "phpbb_"

      sql.gsub("phpbb_", configured_prefix)
    end

    def postgres?
      db_type == :postgres
    end

    def db_type
      @db_type ||= (settings.dig(:source_db, :type) || "mysql").to_sym
    end
  end
end
