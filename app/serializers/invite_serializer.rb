# frozen_string_literal: true

class InviteSerializer < ApplicationSerializer
  attributes :id,
             :invite_key,
             :link,
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
             :expired

  has_many :topics, embed: :object, serializer: BasicTopicSerializer
  has_many :groups, embed: :object, serializer: BasicGroupSerializer

  def include_email?
    options[:show_emails] && !object.redeemed?
  end

  def include_emailed?
    email.present?
  end

  def emailed
    object.emailed_status != Invite.emailed_status_types[:not_required]
  end

  def can_delete_invite
    scope.is_admin? || object.invited_by_id == scope.current_user.id
  end

  def include_custom_message?
    email.present?
  end

  def include_max_redemptions_allowed?
    email.blank?
  end

  def include_redemption_count?
    email.blank?
  end

  def expired
    object.expired?
  end
end
