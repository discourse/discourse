module UserPrimaryGroupMixin

  def self.included(klass)
    klass.attributes :primary_group_name,
                     :primary_group_flair_url,
                     :primary_group_flair_bg_color,
                     :primary_group_flair_color
  end

  def primary_group_name
    object&.primary_group&.name
  end

  def include_primary_group_name?
    object&.primary_group.present?
  end

  def primary_group_flair_url
    object&.primary_group&.flair_url
  end

  def include_primary_group_flair_url?
    object&.primary_group&.flair_url.present?
  end

  def primary_group_flair_bg_color
    object&.primary_group&.flair_bg_color
  end

  def include_primary_group_flair_bg_color?
    object&.primary_group&.flair_bg_color.present?
  end

  def primary_group_flair_color
    object&.primary_group&.flair_color
  end

  def include_primary_group_flair_color?
    object&.primary_group&.flair_color.present?
  end

end
