# frozen_string_literal: true

class CategorySerializer < SiteCategorySerializer
  include BasicCategoryAttributes

  class CategorySettingSerializer < ApplicationSerializer
    attributes :auto_bump_cooldown_days,
               :num_auto_bump_daily,
               :require_reply_approval,
               :require_topic_approval
  end

  class CategoryLocalizationSerializer < ApplicationSerializer
    attributes :id, :locale, :name, :description
  end

  attributes :read_restricted,
             :available_groups,
             :auto_close_hours,
             :auto_close_based_on_last_post,
             :group_permissions,
             :position,
             :email_in,
             :email_in_allow_strangers,
             :mailinglist_mirror,
             :all_topics_wiki,
             :allow_unlimited_owner_edits_on_first_post,
             :can_delete,
             :cannot_delete_reason,
             :is_special,
             :allow_badges,
             :custom_fields,
             :topic_featured_link_allowed,
             :search_priority,
             :moderating_group_ids,
             :default_slow_mode_seconds,
             :style_type,
             :emoji,
             :icon

  has_one :category_setting, serializer: CategorySettingSerializer, embed: :objects
  has_many :category_localizations, serializer: CategoryLocalizationSerializer, embed: :objects

  def include_moderating_group_ids?
    SiteSetting.enable_category_group_moderation?
  end

  def include_category_setting?
    object.association(:category_setting).loaded?
  end

  def group_permissions
    @group_permissions ||=
      begin
        perms =
          object
            .category_groups
            .joins(:group)
            .includes(:group)
            .merge(Group.visible_groups(scope&.user, "groups.name ASC", include_everyone: true))
            .map { |cg| { permission_type: cg.permission_type, group_name: cg.group.name } }

        if perms.length == 0 && !object.read_restricted
          perms << {
            permission_type: CategoryGroup.permission_types[:full],
            group_name: Group[:everyone]&.name.presence || :everyone,
          }
        end

        perms
      end
  end

  def include_group_permissions?
    scope&.can_edit?(object)
  end

  def include_available_groups?
    scope && scope.can_edit?(object)
  end

  def available_groups
    Group.order(:name).pluck(:name) - group_permissions.map { |g| g[:group_name] }
  end

  def can_delete
    true
  end

  def include_is_special?
    [
      SiteSetting.meta_category_id,
      SiteSetting.staff_category_id,
      SiteSetting.uncategorized_category_id,
    ].include? object.id
  end

  def is_special
    true
  end

  def include_can_delete?
    scope && scope.can_delete?(object)
  end

  def include_cannot_delete_reason?
    !include_can_delete? && scope && scope.can_edit?(object)
  end

  def include_email_in?
    scope && scope.can_edit?(object)
  end

  def include_email_in_allow_strangers?
    scope && scope.can_edit?(object)
  end

  def include_notification_level?
    scope && scope.user
  end

  def notification_level
    user = scope && scope.user
    object.notification_level ||
      (user && CategoryUser.where(user: user, category: object).first.try(:notification_level)) ||
      CategoryUser.default_notification_level
  end

  def custom_fields
    object.custom_fields
  end

  def include_custom_fields?
    true
  end

  def name
    category_name
  end

  def description
    category_description
  end
end
