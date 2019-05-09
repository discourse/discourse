require_dependency "migration/base_dropper"

class DbHelper

  REMAP_SQL ||= <<~SQL
    SELECT table_name, column_name
      FROM information_schema.columns
     WHERE table_schema = 'public'
       AND is_updatable = 'YES'
       AND (data_type LIKE 'char%' OR data_type LIKE 'text%')
  ORDER BY table_name, column_name
  SQL

  TRIGGERS_SQL ||= <<~SQL
    SELECT trigger_name
      FROM information_schema.triggers
     WHERE trigger_name LIKE '%_readonly'
  SQL

  def self.remap(from, to, anchor_left: false, anchor_right: false, excluded_tables: [])
    like = "#{anchor_left ? '' : "%"}#{from}#{anchor_right ? '' : "%"}"

    triggers = DB.query(TRIGGERS_SQL).map(&:trigger_name).to_set

    text_columns = Hash.new { |h, k| h[k] = [] }

    DB.query(REMAP_SQL).each do |r|
      unless triggers.include?(Migration::BaseDropper.readonly_trigger_name(r.table_name, r.column_name))
        text_columns[r.table_name] << r.column_name
      end
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
    triggers = DB.query(TRIGGERS_SQL).map(&:trigger_name).to_set

    text_columns = Hash.new { |h, k| h[k] = [] }

    DB.query(REMAP_SQL).each do |r|
      unless triggers.include?(Migration::BaseDropper.readonly_trigger_name(r.table_name, r.column_name))
        text_columns[r.table_name] << r.column_name
      end
    end

    text_columns.each do |table, columns|
      next if excluded_tables.include?(table)

      set = columns.map do |column|
        "#{column} = REGEXP_REPLACE(#{column}, :pattern, :replacement, :flags)"
      end.join(", ")

      where = columns.map do |column|
        "#{column} IS NOT NULL AND #{column} #{match} :pattern"
      end.join(" OR ")

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
        found["#{r.table_name}.#{r.column_name}"] = rows.map do |row|
          row.public_send(r.column_name)
        end
      end
    end

    found
  end

end
