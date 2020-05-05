# frozen_string_literal: true

class InviteSerializer < ApplicationSerializer

  attributes :email, :updated_at, :redeemed_at, :expired, :user
  attribute :created_at, if: :show_created_at?

  def include_email?
    options[:show_emails] && !object.redeemed?
  end

  def expired
    object.expired?
  end

  def user
    ser = InvitedUserSerializer.new(object.user, scope: scope, root: false)
    ser.invited_by = object.invited_by
    ser.as_json
  end

  def show_created_at?
    options[:show_created_at]
  end
end
