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

# 60 minutes after our migration runs we need to exectue this code...
duration = Rails.env.production? ? 60 : 0
if Category.exec_sql("
    SELECT 1 FROM schema_migration_details
    WHERE EXISTS(
      SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE table_schema = 'public' AND table_name = 'categories' AND column_name = 'logo_url'
      ) AND
    name = 'AddUploadsToCategories' AND
    created_at < (current_timestamp at time zone 'UTC' - interval '#{duration} minutes')
  ").to_a.length > 0


  Category.transaction do
    STDERR.puts "Removing superflous category columns!"
    %w[
      logo_url
      background_url
    ].each do |column|
      Category.exec_sql("ALTER TABLE categories DROP column IF EXISTS #{column}")
    end
  end
end
