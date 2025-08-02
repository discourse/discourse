# frozen_string_literal: true

class InvitedSerializer < ApplicationSerializer
  attributes :invites, :can_see_invite_details, :counts

  def invites
    ActiveModel::ArraySerializer.new(
      object.invite_list,
      each_serializer:
        (
          if object.type == "pending" || object.type == "expired"
            InviteSerializer
          else
            InvitedUserSerializer
          end
        ),
      scope: scope,
      root: false,
      show_emails: object.show_emails,
    ).as_json
  end

  def can_see_invite_details
    scope.can_see_invite_details?(object.inviter)
  end

  def counts
    object.counts
  end
end
