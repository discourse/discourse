# frozen_string_literal: true

class ReviewableUserSerializer < ReviewableSerializer
  attributes :link_admin, :user_fields, :reject_reason

  payload_attributes(:username, :email, :name, :bio, :website)

  def link_admin
    scope.is_staff? && object.target.present?
  end

  def user_fields
    object.target.user_fields
  end

  def include_user_fields?
    object.target.present? && object.target.user_fields.present?
  end

  def attributes(*args)
    data = super
    data[:payload]&.delete("email") if !include_email?
    data
  end

  def include_email?
    scope.can_check_emails?(scope.user)
  end
end
