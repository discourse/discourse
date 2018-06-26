class BasicGroupSerializer < ApplicationSerializer
  attributes :id,
             :automatic,
             :name,
             :display_name,
             :user_count,
             :mentionable_level,
             :messageable_level,
             :visibility_level,
             :automatic_membership_email_domains,
             :automatic_membership_retroactive,
             :primary_group,
             :title,
             :grant_trust_level,
             :incoming_email,
             :has_messages,
             :flair_url,
             :flair_bg_color,
             :flair_color,
             :bio_raw,
             :bio_cooked,
             :public_admission,
             :public_exit,
             :allow_membership_requests,
             :full_name,
             :default_notification_level,
             :membership_request_template,
             :is_group_user,
             :is_group_owner

  def include_display_name?
    object.automatic
  end

  def display_name
    if auto_group_name = Group::AUTO_GROUP_IDS[object.id]
      I18n.t("groups.default_names.#{auto_group_name}")
    end
  end

  def include_incoming_email?
    staff?
  end

  def include_has_messages?
    staff? || scope.can_see_group_messages?(object)
  end

  def include_bio_raw?
    staff? || (include_is_group_owner? && is_group_owner)
  end

  def include_is_group_user?
    user_group_ids.present?
  end

  def is_group_user
    user_group_ids.include?(object.id)
  end

  def include_is_group_owner?
    owner_group_ids.present?
  end

  def is_group_owner
    owner_group_ids.include?(object.id)
  end

  private

  def staff?
    @staff ||= scope.is_staff?
  end

  def user_group_ids
    @options[:user_group_ids]
  end

  def owner_group_ids
    @options[:owner_group_ids]
  end
end
