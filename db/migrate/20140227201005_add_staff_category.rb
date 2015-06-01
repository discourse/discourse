class AddStaffCategory < ActiveRecord::Migration
  def up
    unless Rails.env.test?
      result = Category.exec_sql "SELECT 1 FROM site_settings where name = 'staff_category_id'"
      if result.count == 0
        description = I18n.t('staff_category_description')
        name = I18n.t('staff_category_name')

        if Category.exec_sql("SELECT 1 FROM categories where name ilike :name", name: name).count == 0

          result = Category.exec_sql "INSERT INTO categories
                          (name, color, text_color, created_at, updated_at, user_id, slug, description, read_restricted, position)
                   VALUES (:name, '283890', 'FFFFFF', now(), now(), -1, '', :description, true, 2)
                   RETURNING id", name: name, description: description

          category_id = result[0]["id"].to_i

          Category.exec_sql "UPDATE categories SET slug=:slug WHERE id=:category_id",
                  slug: Slug.for(name, "#{category_id}-category"), category_id: category_id

          execute "INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
                   VALUES ('staff_category_id', 3, #{category_id.to_i}, now(), now())"
        end
      end
    end
  end

  def down
    # Do nothing
  end
end
