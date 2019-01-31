class DbHelper

  REMAP_SQL ||= <<~SQL
    SELECT table_name, column_name
      FROM information_schema.columns
     WHERE table_schema = 'public'
       AND is_updatable = 'YES'
       AND (data_type LIKE 'char%' OR data_type LIKE 'text%')
  ORDER BY table_name, column_name
  SQL

  def self.remap(from, to, anchor_left: false, anchor_right: false, excluded_tables: [])
    like = "#{anchor_left ? '' : "%"}#{from}#{anchor_right ? '' : "%"}"
    text_columns = Hash.new { |h, k| h[k] = [] }

    DB.query(REMAP_SQL).each do |r|
      text_columns[r.table_name] << r.column_name
    end

    text_columns.each do |table, columns|
      next if excluded_tables.include?(table)

      set = columns.map do |column|
        "#{column} = REPLACE(#{column}, :from, :to)"
      end.join(", ")

      where = columns.map do |column|
        "#{column} IS NOT NULL AND #{column} LIKE :like"
      end.join(" OR ")

      DB.exec(<<~SQL, from: from, to: to, like: like)
        UPDATE #{table}
           SET #{set}
         WHERE #{where}
      SQL
    end

    SiteSetting.refresh!
  end

  def self.regexp_replace(pattern, replacement, flags: "gi", match: "~*", excluded_tables: [])
    text_columns = Hash.new { |h, k| h[k] = [] }

    DB.query(REMAP_SQL).each do |r|
      text_columns[r.table_name] << r.column_name
    end

    text_columns.each do |table, columns|
      next if excluded_tables.include?(table)

      set = columns.map do |column|
        "#{column} = REGEXP_REPLACE(#{column}, :pattern, :replacement, :flags)"
      end.join(", ")

      where = columns.map do |column|
        "#{column} IS NOT NULL AND #{column} #{match} :pattern"
      end.join(" OR ")

      puts pattern, replacement, flags, match

      DB.exec(<<~SQL, pattern: pattern, replacement: replacement, flags: flags, match: match)
        UPDATE #{table}
           SET #{set}
         WHERE #{where}
      SQL
    end

    SiteSetting.refresh!
  end

  def self.find(needle, anchor_left: false, anchor_right: false, excluded_tables: [])
    found = {}
    like = "#{anchor_left ? '' : "%"}#{needle}#{anchor_right ? '' : "%"}"

    DB.query(REMAP_SQL).each do |r|
      next if excluded_tables.include?(r.table_name)

      rows = DB.query(<<~SQL, like: like)
        SELECT #{r.column_name}
          FROM #{r.table_name}
         WHERE #{r.column_name} LIKE :like
      SQL

      if rows.size > 0
        found["#{r.table_name}.#{r.column_name}"] = rows.map { |row| row.send(r.column_name) }
      end
    end

    found
  end

end
