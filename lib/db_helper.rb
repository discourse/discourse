class DbHelper

  REMAP_SQL ||= "
    SELECT table_name, column_name
      FROM information_schema.columns
     WHERE table_schema = 'public'
       AND is_updatable = 'YES'
       AND (data_type LIKE 'char%' OR data_type LIKE 'text%')
  ORDER BY table_name, column_name"

  def self.remap(from, to)
    connection = ActiveRecord::Base.connection.raw_connection
    remappable_columns = connection.async_exec(REMAP_SQL).to_a
    args = [from, to, "%#{from}%"]

    remappable_columns.each do |rc|
      table_name = rc["table_name"]
      column_name = rc["column_name"]
      connection.async_exec("UPDATE #{table_name} SET #{column_name} = REPLACE(#{column_name}, $1, $2) WHERE #{column_name} LIKE $3", args) rescue nil
    end
  end

end
