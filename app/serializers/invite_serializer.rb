# frozen_string_literal: true

class InviteSerializer < ApplicationSerializer
  attributes :id, :email, :updated_at, :expired

  def include_email?
    options[:show_emails] && !object.redeemed?
  end

  def expired
    object.expired?
  end
end
