class AddUncategorizedCategory < ActiveRecord::Migration[4.2]
  def up

    result = execute "SELECT 1 FROM categories WHERE lower(name) = 'uncategorized'"
    name = 'Uncategorized'
    if result.count > 0
      name << SecureRandom.hex
    end

    result = execute "INSERT INTO categories
            (name,color,slug,description,text_color, user_id, created_at, updated_at, position)
     VALUES ('#{name}', 'AB9364', 'uncategorized', '', 'FFFFFF', -1, now(), now(), 0 )
     RETURNING id
    "
    category_id = result[0]["id"].to_i

    execute "INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
             VALUES ('uncategorized_category_id', 3, #{category_id}, now(), now())"

    execute "DELETE from site_settings where name in ('uncategorized_name', 'uncategorized_text_color', 'uncategorized_color')"

    execute "UPDATE topics SET category_id = #{category_id} WHERE archetype = 'regular' AND category_id IS NULL"

    execute "ALTER table topics ADD CONSTRAINT has_category_id CHECK (category_id IS NOT NULL OR archetype <> 'regular')"

  end

  def down
    execute "ALTER TABLE topics DROP CONSTRAINT has_category_id"
    execute "DELETE from categories WHERE id in (select value::int from site_settings where name = 'uncategorized_category_id')"
    execute "DELETE from site_settings where name = 'uncategorized_category_id'"
    execute "UPDATE topics SET category_id = null WHERE category_id NOT IN (SELECT id from categories)"
  end
end
