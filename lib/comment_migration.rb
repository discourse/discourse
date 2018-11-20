

class CommentMigration < ActiveRecord::Migration[4.2]
  def comments_up
    raise "Not implemented"
  end

  def up
    comments_up.each do |table|
      table[1].each do |column|
        table_name = table[0]
        column_name = column[0]
        comment = column[1]

        if column_name == :_table
          DB.exec "COMMENT ON TABLE #{table_name} IS ?", comment
          puts "  COMMENT ON TABLE #{table_name}"
        else
          DB.exec "COMMENT ON COLUMN #{table_name}.#{column_name} IS ?", comment
          puts "  COMMENT ON COLUMN #{table_name}.#{column_name}"
        end
      end
    end
  end

  def comments_down
    {}
  end

  def down
    replace_nils(comments_up).deep_merge(comments_down).each do |table|
      table[1].each do |column|
        table_name = table[0]
        column_name = column[0]
        comment = column[1]

        if column_name == :_table
          DB.exec "COMMENT ON TABLE #{table_name} IS ?", comment
          puts "  COMMENT ON TABLE #{table_name}"
        else
          DB.exec "COMMENT ON COLUMN #{table_name}.#{column_name} IS ?", comment
          puts "  COMMENT ON COLUMN #{table_name}.#{column_name}"
        end
      end
    end
  end

  private
  def replace_nils(hash)
    hash.each do |key, value|
      if Hash === value
        hash[key] = replace_nils value
      else
        hash[key] = nil
      end
    end
  end
end
