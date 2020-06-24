# frozen_string_literal: true

class InvitedSerializer < ApplicationSerializer
  attributes :invites, :can_see_invite_details

  def invites
    serializer = if object.type == "pending"
      InviteSerializer
    else
      InvitedUserSerializer
    end

    ActiveModel::ArraySerializer.new(
      object.invite_list,
      each_serializer: serializer,
      scope: scope,
      root: false,
      show_emails: object.show_emails
    ).as_json
  end

  def can_see_invite_details
    scope.can_see_invite_details?(object.inviter)
  end

  def read_attribute_for_serialization(attr)
    object.respond_to?(attr) ? object.public_send(attr) : public_send(attr)
  end
end
