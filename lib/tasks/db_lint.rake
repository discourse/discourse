# frozen_string_literal: true

namespace :db do
  desc "Lint database associations for foreign key/primary key type mismatches"
  task lint: :environment do
    # If RAILS_ENV is not explicitly set, re-exec with test
    unless ENV.key?("RAILS_ENV")
      puts I18n.t("rake.db_lint.reexec")
      exec({ "RAILS_ENV" => "test" }, "bin/rake db:lint")
    end

    puts I18n.t("rake.db_lint.starting")

    # Ensure all models are loaded so reflections are available
    Rails.application.eager_load!

    connection = ActiveRecord::Base.connection
    mismatches = []

    # Build a cache of table -> { column_name => column } for faster lookups
    columns_cache =
      Hash.new do |h, table|
        h[table] = connection.columns(table).each_with_object({}) { |col, acc| acc[col.name] = col }
      end

    only = ENV["DB_LINT_ONLY"]&.split(",")&.map(&:strip)
    db_lint_models.each do |model|
      next if only && !only.include?(model.name)
      # Skip abstract models or ones without tables
      next if model.abstract_class?
      next unless model.table_exists?

      model
        .reflections
        .values
        .select { |r| r.macro == :belongs_to }
        .each do |reflection|
          # Skip polymorphic associations since target is dynamic
          next if reflection.polymorphic?

          fk = reflection.foreign_key.to_s
          owner_table = model.table_name

          fk_col = columns_cache[owner_table][fk]
          next unless fk_col # skip if the fk column doesn't exist

          begin
            target_class = reflection.klass
          rescue NameError
            # Target class could not be resolved; skip
            next
          end

          next if target_class.abstract_class?
          next unless target_class.table_exists?

          pk_name = reflection.options[:primary_key] || target_class.primary_key
          target_table = target_class.table_name
          pk_col = columns_cache[target_table][pk_name]
          next unless pk_col

          fk_kind = normalize_integer_kind(fk_col)
          pk_kind = normalize_integer_kind(pk_col)

          if integer_like?(fk_kind) || integer_like?(pk_kind)
            # For integer-like types, require exact match (:integer vs :bigint)
            if fk_kind != pk_kind
              mismatches << {
                owner: model.name,
                assoc: reflection.name,
                target: target_class.name,
                owner_table: owner_table,
                fk: fk,
                fk_type: human_type(fk_col),
                target_table: target_table,
                pk: pk_name,
                pk_type: human_type(pk_col),
              }
            end
          else
            # For non-integer-like, require exact SQL type match
            if pk_col.sql_type != fk_col.sql_type
              mismatches << {
                owner: model.name,
                assoc: reflection.name,
                target: target_class.name,
                owner_table: owner_table,
                fk: fk,
                fk_type: human_type(fk_col),
                target_table: target_table,
                pk: pk_name,
                pk_type: human_type(pk_col),
              }
            end
          end
        end
    end

    if mismatches.empty?
      puts I18n.t("rake.db_lint.ok")
    else
      puts I18n.t("rake.db_lint.error_header")
      mismatches.each do |m|
        puts I18n.t(
               "rake.db_lint.mismatch",
               owner: m[:owner],
               assoc: m[:assoc],
               target: m[:target],
               owner_table: m[:owner_table],
               fk: m[:fk],
               fk_type: m[:fk_type],
               target_table: m[:target_table],
               pk: m[:pk],
               pk_type: m[:pk_type],
             )
      end
      puts I18n.t("rake.db_lint.summary", count: mismatches.length)
      abort
    end
  end
end

def db_lint_models
  ActiveRecord::Base.descendants
end

def integer_like?(kind)
  kind == :integer || kind == :bigint
end

def normalize_integer_kind(column)
  # Prefer SQL type metadata first, as some adapters map bigint to :integer
  sql = column.sql_type.to_s.downcase
  return :bigint if sql.include?("bigint") || sql.include?("int8")
  return :integer if sql.include?("integer") || sql.include?("int4") || sql.include?("int")
  # Fallback to adapter-reported type
  return :bigint if column.type == :bigint
  return :integer if column.type == :integer
  column.type
end

def human_type(column)
  # Provide a readable type string for messages
  kind = normalize_integer_kind(column)
  return kind.to_s if integer_like?(kind)

  t = column.type
  lim = (column.respond_to?(:limit) ? column.limit : nil)
  sql = column.sql_type
  return "#{t}(#{lim})" if lim
  sql || t.to_s
end
