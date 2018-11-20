class SqlBuilder

  def initialize(template, klass = nil)

    Discourse.deprecate("SqlBuilder is deprecated and will be removed, please use DB.build instead!")

    @args = {}
    @sql = template
    @sections = {}
    @klass = klass
  end

  [:set, :where2, :where, :order_by, :limit, :left_join, :join, :offset, :select].each do |k|
    define_method k do |data, args = {}|
      @args.merge!(args)
      @sections[k] ||= []
      @sections[k] << data
      self
    end
  end

  def secure_category(secure_category_ids, category_alias = 'c')
    if secure_category_ids.present?
      where("NOT COALESCE(" << category_alias << ".read_restricted, false) OR " << category_alias << ".id IN (:secure_category_ids)", secure_category_ids: secure_category_ids)
    else
      where("NOT COALESCE(" << category_alias << ".read_restricted, false)")
    end
    self
  end

  def to_sql
    sql = @sql.dup

    @sections.each do |k, v|
      joined = nil
      case k
      when :select
        joined = "SELECT " << v.join(" , ")
      when :where, :where2
        joined = "WHERE " << v.map { |c| "(" << c << ")" }.join(" AND ")
      when :join
        joined = v.map { |item| "JOIN " << item }.join("\n")
      when :left_join
        joined = v.map { |item| "LEFT JOIN " << item }.join("\n")
      when :limit
        joined = "LIMIT " << v.last.to_s
      when :offset
        joined = "OFFSET " << v.last.to_s
      when :order_by
        joined = "ORDER BY " << v.join(" , ")
      when :set
        joined = "SET " << v.join(" , ")
      end

      sql.sub!("/*#{k}*/", joined)
    end
    sql
  end

  def exec(args = {})
    @args.merge!(args)

    sql = to_sql
    if @klass
      @klass.find_by_sql(ActiveRecord::Base.send(:sanitize_sql_array, [sql, @args]))
    else
      if @args == {}
        ActiveRecord::Base.exec_sql(sql)
      else
        ActiveRecord::Base.exec_sql(sql, @args)
      end
    end
  end

  def self.map_exec(klass, sql, args = {})
    self.new(sql).map_exec(klass, args)
  end

  class RailsDateTimeDecoder < PG::SimpleDecoder
    def decode(string, tuple = nil, field = nil)
      @caster ||= ActiveRecord::Type::DateTime.new
      @caster.cast(string)
    end
  end

  class ActiveRecordTypeMap < PG::BasicTypeMapForResults
    def initialize(connection)
      super(connection)
      rm_coder 0, 1114
      add_coder RailsDateTimeDecoder.new(name: "timestamp", oid: 1114, format: 0)
       # we don't need deprecations
       self.default_type_map = PG::TypeMapInRuby.new
    end
  end

  def self.pg_type_map
    conn = ActiveRecord::Base.connection.raw_connection
    @typemap ||= ActiveRecordTypeMap.new(conn)
  end

  def map_exec(klass = OpenStruct, args = {})
    results = exec(args)
    results.type_map = SqlBuilder.pg_type_map

    setters = results.fields.each_with_index.map do |f, index|
      f.dup << "="
    end

    values = results.values
    values.map! do |row|
      mapped = klass.new
      setters.each_with_index do |name, index|
        mapped.send name, row[index]
      end
      mapped
    end
  end

end
