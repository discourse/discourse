class AddLoungeCategory < ActiveRecord::Migration
  def up
    unless Rails.env.test?
      result = Category.exec_sql "SELECT 1 FROM site_settings where name = 'lounge_category_id'"
      if result.count == 0
        description = I18n.t('vip_category_description')

        default_name = I18n.t('vip_category_name')
        name = if Category.exec_sql("SELECT 1 FROM categories where name = '#{default_name}'").count == 0
          default_name
        else
          "CHANGE_ME"
        end

        result = execute "INSERT INTO categories
                        (name, color, text_color, created_at, updated_at, user_id, slug, description, read_restricted, position)
                 VALUES ('#{name}', 'EEEEEE', '652D90', now(), now(), -1, '#{Slug.for(name)}', '#{description}', true, 3)
                 RETURNING id"
        category_id = result[0]["id"].to_i

        execute "INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
                 VALUES ('lounge_category_id', 3, #{category_id}, now(), now())"
      end
    end
  end

  def down
    # Don't reverse this change. There is so much logic around deleting a category that it's messy
    # to try to do in sql. The up method will just make sure never to create the category twice.
  end
end
