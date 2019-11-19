# frozen_string_literal: true

module Jobs

  class ProcessBulkInviteEmails < ::Jobs::Base

    def execute(args)
      pending_invite_ids = Invite.where(emailed_status: Invite.emailed_status_types[:bulk_pending]).limit(Invite::BULK_INVITE_EMAIL_LIMIT).pluck(:id)

      if pending_invite_ids.length > 0
        Invite.where(id: pending_invite_ids).update_all(emailed_status: Invite.emailed_status_types[:sending])
        pending_invite_ids.each do |invite_id|
          ::Jobs.enqueue(:invite_email, invite_id: invite_id)
        end
        ::Jobs.enqueue_in(1.minute, :process_bulk_invite_emails)
      end
    end
  end
end
