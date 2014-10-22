class BasicCategorySerializer < ApplicationSerializer

  attributes :id,
             :name,
             :color,
             :text_color,
             :slug,
             :topic_count,
             :post_count,
             :description,
             :description_text,
             :topic_url,
             :read_restricted,
             :permission,
             :parent_category_id,
             :notification_level,
             :logo_url,
             :background_url,
             :can_edit

  def include_parent_category_id?
    parent_category_id
  end

  def description
    object.uncategorized? ? SiteSetting.uncategorized_description : object.description
  end

  def can_edit
    true
  end

  def include_can_edit?
    scope && scope.can_edit?(object)
  end

end
