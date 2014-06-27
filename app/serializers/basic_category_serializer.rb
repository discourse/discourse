class BasicCategorySerializer < ApplicationSerializer

  attributes :id,
             :name,
             :color,
             :text_color,
             :slug,
             :topic_count,
             :post_count,
             :description,
             :topic_url,
             :read_restricted,
             :permission,
             :parent_category_id,
             :notification_level,
             :logo_url,
             :background_url

  def include_parent_category_id?
    parent_category_id
  end

  def description
    object.uncategorized? ? SiteSetting.uncategorized_description : object.description
  end
end
