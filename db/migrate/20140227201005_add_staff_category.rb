class AddStaffCategory < ActiveRecord::Migration[4.2]
  def up
    return if Rails.env.test?

    I18n.overrides_disabled do
      result = DB.exec "SELECT 1 FROM site_settings where name = 'staff_category_id'"
      if result == 0
        description = I18n.t('staff_category_description')
        name = I18n.t('staff_category_name')

        if DB.exec("SELECT 1 FROM categories where name ilike :name", name: name) == 0

          result = DB.query_single "INSERT INTO categories
                          (name, color, text_color, created_at, updated_at, user_id, slug, description, read_restricted, position)
                   VALUES (:name, 'E45735', 'FFFFFF', now(), now(), -1, '', :description, true, 2)
                   RETURNING id", name: name, description: description

          category_id = result.first.to_i

          DB.exec "UPDATE categories SET slug=:slug WHERE id=:category_id",
                  slug: Slug.for(name, "#{category_id}-category"), category_id: category_id

          DB.exec "INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
                   VALUES ('staff_category_id', 3, #{category_id.to_i}, now(), now())"
        end
      end
    end
  end

  def down
    # Do nothing
  end
end
