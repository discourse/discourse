require 'column_dropper'

# fix any bust caches post initial migration
ActiveRecord::Base.send(:subclasses).each { |m| m.reset_column_information }

SiteSetting.refresh!
uncat_id = SiteSetting.uncategorized_category_id
uncat_id = -1 unless Numeric === uncat_id

if uncat_id == -1 || !Category.exists?(uncat_id)
  puts "Seeding uncategorized category!"

  result = Category.exec_sql "SELECT 1 FROM categories WHERE lower(name) = 'uncategorized'"
  name = 'Uncategorized'
  name << SecureRandom.hex if result.count > 0

  result = Category.exec_sql "INSERT INTO categories
          (name,color,slug,description,text_color, user_id, created_at, updated_at, position, name_lower)
   VALUES ('#{name}', 'AB9364', 'uncategorized', '', 'FFFFFF', -1, now(), now(), 1, '#{name.downcase}' )
   RETURNING id
  "
  category_id = result[0]["id"].to_i

  Category.exec_sql "DELETE FROM site_settings where name = 'uncategorized_category_id'"
  Category.exec_sql "INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
           VALUES ('uncategorized_category_id', 3, #{category_id}, now(), now())"
end

ColumnDropper.drop(
  table: 'categories',
  after_migration: 'AddSuppressFromLatestToCategories',
  columns: ['logo_url', 'background_url', 'suppress_from_homepage'],
  on_drop: ->() {
    STDERR.puts 'Removing superflous categories columns!'
  }
)
