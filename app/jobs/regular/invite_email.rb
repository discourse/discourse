# frozen_string_literal: true

module Jobs
  # Asynchronously send an email
  class InviteEmail < ::Jobs::Base
    def execute(args)
      raise Discourse::InvalidParameters.new(:invite_id) if args[:invite_id].blank?

      invite = Invite.find_by(id: args[:invite_id])
      return if invite.blank?

      message = InviteMailer.send_invite(invite, invite_to_topic: args[:invite_to_topic])
      Email::Sender.new(message, :invite).send

      if invite.emailed_status != Invite.emailed_status_types[:not_required]
        invite.update_column(:emailed_status, Invite.emailed_status_types[:sent])
      end
    end
  end
end
