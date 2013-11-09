SiteSetting.refresh!
if SiteSetting.uncategorized_category_id == -1
  puts "Seeding uncategorized category!"

  result = Category.exec_sql "SELECT 1 FROM categories WHERE name = 'uncategorized'"
  name = 'uncategorized'
  if result.count > 0
    name << SecureRandom.hex
  end

  result = Category.exec_sql "INSERT INTO categories
          (name,color,slug,description,text_color, user_id, created_at, updated_at, position)
   VALUES ('#{name}', 'AB9364', 'uncategorized', '', 'FFFFFF', -1, now(), now(), 1 )
   RETURNING id
  "
  category_id = result[0]["id"].to_i

  Category.exec_sql "INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
           VALUES ('uncategorized_category_id', 3, #{category_id}, now(), now())"
end
