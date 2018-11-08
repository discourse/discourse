class DbHelper

  REMAP_SQL ||= "
    SELECT table_name, column_name
      FROM information_schema.columns
     WHERE table_schema = 'public'
       AND is_updatable = 'YES'
       AND (data_type LIKE 'char%' OR data_type LIKE 'text%')
  ORDER BY table_name, column_name"

  def self.remap(from, to, anchor_left: false, anchor_right: false, exclude_tables: [])
    results = DB.query(REMAP_SQL).to_a
    like = "#{anchor_left ? '' : "%"}#{from}#{anchor_right ? '' : "%"}"

    remappable_columns = {}

    results.each do |result|
      remappable_columns[result.table_name] ||= []
      remappable_columns[result.table_name] << result.column_name
    end

    exclude_tables = exclude_tables.map(&:to_s)

    remappable_columns.each do |table_name, column_names|
      next if exclude_tables.include?(table_name)
      set_clause = column_names.map do |column_name|
        "#{column_name} = REPLACE(#{column_name}, :from, :to)"
      end.join(", ")

      where_clause = column_names.map do |column_name|
        "#{column_name} LIKE :like"
      end.join(" OR ")

      DB.exec(<<~SQL, from: from, to: to, like: like)
        UPDATE #{table_name}
        SET #{set_clause}
        WHERE #{where_clause}
      SQL
    end

    SiteSetting.refresh!
  end

  def self.find(needle, anchor_left = false, anchor_right = false)
    connection = ActiveRecord::Base.connection.raw_connection
    text_columns = connection.async_exec(REMAP_SQL).to_a
    args = ["#{anchor_left ? '' : "%"}#{needle}#{anchor_right ? '' : "%"}"]
    found = {}

    text_columns.each do |rc|
      table_name = rc["table_name"]
      column_name = rc["column_name"]
      result = connection.async_exec("SELECT #{column_name} FROM #{table_name} WHERE #{column_name} LIKE $1", args) rescue nil
      if result&.ntuples > 0
        found["#{table_name}.#{column_name}"] = result.map { |r| r[column_name] }
      end
    end
    found
  end

end
