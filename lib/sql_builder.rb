class SqlBuilder

  def initialize(template)
    @args = {}
    @sql = template
    @sections = {}
  end

  [:set, :where2,:where,:order_by,:limit,:left_join,:join,:offset].each do |k|
    define_method k do |data, args = {}|
      @args.merge!(args)
      @sections[k] ||= []
      @sections[k] << data
      self
    end
  end

  def exec(args = {})
    sql = @sql.dup
    @args.merge!(args)

    @sections.each do |k,v|
      joined = nil
      case k 
      when :where, :where2
        joined = "WHERE " << v.join(" AND ")
      when :join
        joined = v.map{|v| "JOIN " << v }.join("\n")
      when :left_join
        joined = v.map{|v| "LEFT JOIN " << v }.join("\n")
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

    ActiveRecord::Base.exec_sql(sql,@args)
  end


end
