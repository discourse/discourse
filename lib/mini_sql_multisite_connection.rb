# frozen_string_literal: true

class MiniSqlMultisiteConnection < MiniSql::Postgres::Connection

  class CustomBuilder < MiniSql::Builder

    def initialize(connection, sql)
      super
    end

    def secure_category(secure_category_ids, category_alias = 'c')
      if secure_category_ids.present?
        where("NOT COALESCE(#{category_alias}.read_restricted, false) OR #{category_alias}.id in (:secure_category_ids)", secure_category_ids: secure_category_ids)
      else
        where("NOT COALESCE(#{category_alias}.read_restricted, false)")
      end
      self
    end
  end

  class ParamEncoder
    def encode(*sql_array)
      # use active record to avoid any discrepencies
      ActiveRecord::Base.public_send(:sanitize_sql_array, sql_array)
    end
  end

  class AfterCommitWrapper
    def initialize(&blk)
      raise ArgumentError, "tried to create a Proc without a block in AfterCommitWrapper" if !blk
      @callback = blk
    end

    def committed!(*)
      @callback.call
    end

    def before_committed!(*); end
    def rolledback!(*); end
    def trigger_transactional_callbacks?
      true
    end
  end

  # Allows running arbitrary code after the current transaction has been committed.
  # Works even with nested transactions. Useful for scheduling sidekiq jobs.
  def after_commit(&blk)
    ActiveRecord::Base.connection.add_transaction_record(
      AfterCommitWrapper.new(&blk)
    )
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
