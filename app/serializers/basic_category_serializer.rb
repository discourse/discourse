class BasicCategorySerializer < ApplicationSerializer

  attributes :id,
             :name,
             :color,
             :text_color,
             :slug,
             :topic_count,
             :description,
             :topic_url,
             :read_restricted,
             :permission,
             :parent_category_id

  def include_parent_category_id?
    parent_category_id
  end

end
