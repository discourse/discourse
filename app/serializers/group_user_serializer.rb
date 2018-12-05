class GroupUserSerializer < BasicUserSerializer
  attributes :name,
             :title,
             :last_posted_at,
             :last_seen_at,
             :added_at,
             :primary_group_name,
             :primary_group_flair_url,
             :primary_group_flair_bg_color,
             :primary_group_flair_color

  def include_added_at
    object.respond_to? :added_at
  end

  def primary_group_name
    return nil unless object&.primary_group_id
    object&.primary_group&.name
  end

  def primary_group_flair_url
    object&.primary_group&.flair_url
  end

  def primary_group_flair_bg_color
    object&.primary_group&.flair_bg_color
  end

  def primary_group_flair_color
    object&.primary_group&.flair_color
  end
end
