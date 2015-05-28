class AddMetaCategory < ActiveRecord::Migration
  def up
    unless Rails.env.test?
      result = Category.exec_sql "SELECT 1 FROM site_settings where name = 'meta_category_id'"
      if result.count == 0
        description = I18n.t('meta_category_description')
        name = I18n.t('meta_category_name')

        if Category.exec_sql("SELECT 1 FROM categories where name ilike :name", name: name).count == 0
          result = Category.exec_sql "INSERT INTO categories
                          (name, color, text_color, created_at, updated_at, user_id, slug, description, read_restricted, position)
                   VALUES (:name, '808281', 'FFFFFF', now(), now(), -1, :slug, :description, true, 1)
                   RETURNING id", name: name, slug: '', description: description

          category_id = result[0]["id"].to_i

          Category.exec_sql "UPDATE categories SET slug=:slug WHERE id=:category_id",
                    slug: Slug.for(name, "#{category_id}-category"), category_id: category_id

          execute "INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
                   VALUES ('meta_category_id', 3, #{category_id}, now(), now())"
        end

      end
    end
  end

  def down
    # Don't reverse this change. There is so much logic around deleting a category that it's messy
    # to try to do in sql. The up method will just make sure never to create the category twice.
  end
end
