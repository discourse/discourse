# frozen_string_literal: true

# Compiles a single-row ActiveRecord query that LEFT JOINs a tree of singular
# (`belongs_to` / `has_one`) associations outside a `LIMIT 1` derived table.
# Avoids ActiveRecord::Associations::JoinDependency's per-call AST, column-aliasing,
# and collection-deduplication overhead while hydrating standard AR records.
class SingularJoin
  JoinNode =
    Data.define(
      :index,
      :parent_index,
      :alias_name,
      :sentinel,
      :association_name,
      :klass,
      :primary_key,
      :inverse_name,
    )
  private_constant :JoinNode

  Plan = Data.define(:models, :watched_columns, :nodes, :sentinels, :sql)
  private_constant :Plan

  # The block runs once per schema snapshot (process-wide across multisites), so keep it
  # site- and time-independent and pass dynamic/per-site values as named :binds to #first.
  def self.compile(root_klass, with:, query_name: nil, &block)
    new(root_klass, with:, query_name:, &block)
  end

  def initialize(root_klass, with:, query_name: nil, &block)
    raise ArgumentError, "A base query block is required" if !block
    raise ArgumentError, "with: must specify at least one association" if with.blank?

    @root_klass = root_klass
    @with = with
    @query_name = query_name || "#{root_klass.name} Load"
    @base_query_block = block
    @plan = nil
  end

  def first(comment: nil, **binds)
    plan = nil
    result =
      @root_klass.with_connection do |connection|
        plan = compiled_plan(connection)
        sql = binds.empty? ? plan.sql : @root_klass.sanitize_sql_array([plan.sql, binds])
        if comment
          sanitized = comment.to_s.gsub("/*", "/ *").gsub("*/", "* /").tr("\r\n", " ")
          sql = "#{sql} /* #{sanitized} */"
        end
        connection.select_all(sql, @query_name, allow_retry: true)
      end

    row = result.rows.first
    return nil if !row

    hydrate(plan, result.columns, row)
  end

  private

  def compiled_plan(connection)
    plan = @plan
    return plan if plan_current?(plan)

    @plan = build_plan(connection)
  end

  def plan_current?(plan)
    return false if !plan

    models = plan.models
    watched = plan.watched_columns
    i = 0
    len = models.length
    while i < len
      # Active Record replaces a model's frozen column_names array on schema reload
      # (including ignored_columns=); pointer identity avoids hashing column names.
      return false if !watched[i].equal?(models[i].column_names)
      i += 1
    end
    true
  end

  def build_plan(connection)
    relation = @root_klass.instance_exec(&@base_query_block)
    if !relation.is_a?(ActiveRecord::Relation) || relation.klass != @root_klass
      raise ArgumentError,
            "SingularJoin block must return a #{@root_klass.name} ActiveRecord::Relation"
    end
    if relation.eager_load_values.any? || relation.includes_values.any? ||
         relation.preload_values.any?
      raise ArgumentError, "Pass associations via with: instead of eager_load/includes/preload"
    end
    relation = relation.limit(1) if relation.limit_value.nil?

    nodes = []
    selects = ["t0.*"]
    joins = []
    collect_nodes(@root_klass, 0, @with, nodes, selects, joins, connection)

    sql = <<~SQL.freeze
      SELECT #{selects.join(",\n       ")}
      FROM (#{relation.to_sql}) t0
      #{joins.join("\n")}
    SQL

    models = [@root_klass, *nodes.map(&:klass)].uniq.freeze
    watched_columns = models.map(&:column_names).freeze
    sentinels = nodes.map(&:sentinel).freeze

    Plan.new(models:, watched_columns:, nodes: nodes.freeze, sentinels:, sql:)
  end

  def collect_nodes(parent_klass, parent_index, spec, nodes, selects, joins, connection)
    normalize_spec(spec).each do |assoc_name, nested_spec|
      reflection = validate_reflection!(parent_klass, assoc_name)
      target_klass = reflection.klass
      target_pk = target_klass.primary_key
      if target_pk.blank? || target_pk.is_a?(Array)
        raise ArgumentError, "#{target_klass.name} must have a single primary key"
      end

      index = nodes.length + 1
      alias_name = "t#{index}"
      parent_alias = "t#{parent_index}"
      sentinel = "__sj#{index}"

      quoted_table = connection.quote_table_name(target_klass.table_name)
      quoted_pk = connection.quote_column_name(reflection.join_primary_key)
      quoted_fk = connection.quote_column_name(reflection.join_foreign_key)

      selects << %Q{NULL AS "#{sentinel}"}
      selects << projection_for(connection, alias_name, target_klass)
      joins << "LEFT JOIN #{quoted_table} #{alias_name} ON #{alias_name}.#{quoted_pk} = #{parent_alias}.#{quoted_fk}"

      inverse = reflection.inverse_of
      inverse_name = inverse.name if inverse && !inverse.collection?

      nodes << JoinNode.new(
        index:,
        parent_index:,
        alias_name:,
        sentinel:,
        association_name: reflection.name,
        klass: target_klass,
        primary_key: target_pk.to_s,
        inverse_name:,
      )

      if nested_spec
        collect_nodes(target_klass, index, nested_spec, nodes, selects, joins, connection)
      end
    end
  end

  def normalize_spec(spec)
    case spec
    when Symbol, String
      [[spec.to_sym, nil]]
    when Array
      spec.flat_map { |item| normalize_spec(item) }
    when Hash
      spec.map { |name, nested| [name.to_sym, nested] }
    else
      raise ArgumentError, "Unsupported with: specification: #{spec.inspect}"
    end
  end

  def validate_reflection!(parent_klass, assoc_name)
    reflection = parent_klass.reflect_on_association(assoc_name)
    raise ArgumentError, "Unknown association :#{assoc_name} on #{parent_klass.name}" if !reflection
    if reflection.macro != :belongs_to && reflection.macro != :has_one
      raise ArgumentError,
            "SingularJoin only supports belongs_to and has_one (got #{reflection.macro} :#{assoc_name} on #{parent_klass.name})"
    end
    if reflection.polymorphic?
      raise ArgumentError,
            "Polymorphic association :#{assoc_name} on #{parent_klass.name} is not supported"
    end
    if reflection.through_reflection?
      raise ArgumentError,
            "Through association :#{assoc_name} on #{parent_klass.name} is not supported"
    end
    if reflection.scope
      raise ArgumentError,
            "Scoped association :#{assoc_name} on #{parent_klass.name} is not supported"
    end
    if reflection.join_primary_key.is_a?(Array) || reflection.join_foreign_key.is_a?(Array)
      raise ArgumentError,
            "Composite keys on :#{assoc_name} on #{parent_klass.name} are not supported"
    end
    if reflection.klass.default_scopes.any?
      raise ArgumentError,
            "Target model #{reflection.klass.name} for :#{assoc_name} has default_scopes which are not supported"
    end

    reflection
  end

  def projection_for(connection, table_alias, klass)
    return "#{table_alias}.*" if klass.ignored_columns.empty? && klass.only_columns.blank?

    klass
      .column_names
      .map { |column| "#{table_alias}.#{connection.quote_column_name(column)}" }
      .join(", ")
  end

  def hydrate(plan, columns, row)
    nodes = plan.nodes
    hashes = Array.new(nodes.length + 1) { {} }
    sentinels = plan.sentinels

    part = 0
    current = hashes[0]
    next_sentinel = sentinels[0]
    i = 0
    len = columns.length
    while i < len
      column = columns[i]
      if column == next_sentinel
        part += 1
        current = hashes[part]
        next_sentinel = sentinels[part]
      else
        current[column] = row[i]
      end
      i += 1
    end

    records = Array.new(nodes.length + 1)
    records[0] = @root_klass.instantiate(hashes[0])

    nodes.each do |node|
      parent = records[node.parent_index]
      next if !parent

      attrs = hashes[node.index]
      child = nil
      if attrs[node.primary_key]
        child = node.klass.instantiate(attrs)
        child.association(node.inverse_name).target = parent if node.inverse_name
        records[node.index] = child
      end
      # Assigning #target= marks the association loaded (including nil) so callers don't re-query.
      parent.association(node.association_name).target = child
    end

    records[0]
  end
end
