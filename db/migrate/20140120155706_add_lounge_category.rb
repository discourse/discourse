class AddLoungeCategory < ActiveRecord::Migration[4.2]
  def up
    return if Rails.env.test?

    I18n.overrides_disabled do
      result = DB.exec "SELECT 1 FROM site_settings where name = 'lounge_category_id'"
      if result == 0
        description = I18n.t('vip_category_description')

        default_name = I18n.t('vip_category_name')
        name = if DB.exec("SELECT 1 FROM categories where name = '#{default_name}'") == 0
          default_name
        else
          "CHANGE_ME"
        end

        result = DB.query_single "INSERT INTO categories
                        (name, color, text_color, created_at, updated_at, user_id, slug, description, read_restricted, position)
                 VALUES (:name, 'A461EF', '652D90', now(), now(), -1, '', :description, true, 3)
                 RETURNING id", name: name, description: description

        category_id = result.first.to_i

        DB.exec "UPDATE categories SET slug = :slug
                          WHERE id = :category_id",
                          slug: Slug.for(name, "#{category_id}-category"), category_id: category_id

        execute "INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
                 VALUES ('lounge_category_id', 3, #{category_id.to_i}, now(), now())"
      end
    end
  end

  def down
    # Don't reverse this change. There is so much logic around deleting a category that it's messy
    # to try to do in sql. The up method will just make sure never to create the category twice.
  end
end
