# frozen_string_literal: true

module UserPrimaryGroupMixin

  def self.included(klass)
    klass.attributes :primary_group_name,
                     :flair_name,
                     :flair_url,
                     :flair_bg_color,
                     :flair_color,
                     :admin,
                     :moderator,
                     :trust_level
  end

  def primary_group_name
    object&.primary_group&.name
  end

  def include_primary_group_name?
    object&.primary_group.present?
  end

  def flair_name
    object&.flair_group&.name
  end

  def include_flair_group_name?
    object&.flair_group.present?
  end

  def flair_url
    object&.flair_group&.flair_url
  end

  def include_flair_url?
    object&.flair_group&.flair_url.present?
  end

  def flair_bg_color
    object&.flair_group&.flair_bg_color
  end

  def include_flair_bg_color?
    object&.flair_group&.flair_bg_color.present?
  end

  def flair_color
    object&.flair_group&.flair_color
  end

  def include_flair_color?
    object&.flair_group&.flair_color.present?
  end

  def include_admin?
    object&.admin
  end

  def admin
    true
  end

  def include_moderator?
    object&.moderator
  end

  def moderator
    true
  end
end
