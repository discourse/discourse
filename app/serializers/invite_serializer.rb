# frozen_string_literal: true

class InviteSerializer < ApplicationSerializer
  attributes :id,
             :invite_key,
             :link,
             :description,
             :email,
             :domain,
             :emailed,
             :can_delete_invite,
             :max_redemptions_allowed,
             :redemption_count,
             :custom_message,
             :created_at,
             :updated_at,
             :expires_at,
             :expired,
             :grants_admin

  has_many :topics, embed: :object, serializer: BasicTopicSerializer
  has_many :groups, embed: :object, serializer: BasicGroupSerializer

  def include_invite_key?
    can_see_invite_details?
  end

  def include_link?
    can_see_invite_details?
  end

  def include_description?
    can_see_invite_details?
  end

  def include_email?
    options[:show_emails] && !object.redeemed? && can_see_invite_emails?
  end

  def include_domain?
    can_see_invite_details?
  end

  def include_emailed?
    email.present? && can_see_invite_details?
  end

  def emailed
    object.emailed_status != Invite.emailed_status_types[:not_required]
  end

  def can_delete_invite
    scope.can_destroy_invite?(object)
  end

  def include_custom_message?
    email.present? && can_see_invite_details?
  end

  def include_max_redemptions_allowed?
    email.blank? && can_see_invite_details?
  end

  def include_redemption_count?
    email.blank? && can_see_invite_details?
  end

  def include_topics?
    can_see_invite_details?
  end

  def topics
    object.topics.select { |topic| scope.can_see?(topic) }
  end

  def include_groups?
    can_see_invite_details?
  end

  def expired
    object.expired?
  end

  def grants_admin
    object.admin?
  end

  def include_grants_admin?
    can_see_invite_details?
  end

  private

  def can_see_invite_details?
    return @can_see_invite_details if defined?(@can_see_invite_details)

    @can_see_invite_details = scope.can_see_invite_details?(object.invited_by)
  end

  def can_see_invite_emails?
    return @can_see_invite_emails if defined?(@can_see_invite_emails)

    @can_see_invite_emails = scope.can_see_invite_emails?(object.invited_by)
  end
end
