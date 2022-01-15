# frozen_string_literal: true

class InviteSerializer < ApplicationSerializer
  attributes :id,
             :invite_key,
             :link,
             :email,
             :domain,
             :emailed,
             :max_redemptions_allowed,
             :redemption_count,
             :custom_message,
             :created_at,
             :updated_at,
             :expires_at,
             :expired,
             :warnings

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

  def warnings
    object.warnings(scope)
  end

  def include_warnings?
    object.warnings(scope).present?
  end
end
