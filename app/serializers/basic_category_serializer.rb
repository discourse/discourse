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
             :notification_level

  def include_parent_category_id?
    parent_category_id
  end
end
