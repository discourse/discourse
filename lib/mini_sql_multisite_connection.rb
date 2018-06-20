class MiniSqlMultisiteConnection < MiniSql::Connection

  class CustomBuilder < MiniSql::Builder

    def initialize(connection, sql)
      super
    end

    def secure_category(secure_category_ids, category_alias = 'c')
      if secure_category_ids.present?
        where("NOT COALESCE(" << category_alias << ".read_restricted, false) OR " << category_alias << ".id in (:secure_category_ids)", secure_category_ids: secure_category_ids)
      else
        where("NOT COALESCE(" << category_alias << ".read_restricted, false)")
      end
      self
    end
  end

  class ParamEncoder
    def encode(*sql_array)
      # use active record to avoid any discrepencies
      ActiveRecord::Base.send(:sanitize_sql_array, sql_array)
    end
  end

  def self.instance
    new(nil, param_encoder: ParamEncoder.new)
  end

  # we need a tiny adapter here so we always run against the
  # correct multisite connection
  def raw_connection
    ActiveRecord::Base.connection.raw_connection
  end

  def build(sql)
    CustomBuilder.new(self, sql)
  end

  def sql_fragment(query, *args)
    if args.length > 0
      param_encoder.encode(query, *args)
    else
      query
    end
  end

end
