# frozen_string_literal: true

require 'rails_helper'

describe Jobs::ProcessBulkInviteEmails do
  describe '#execute' do
    it 'processes pending invites' do
      invite = Fabricate(:invite, emailed_status: Invite.emailed_status_types[:bulk_pending])

      described_class.new.execute({})

      invite.reload
      expect(invite.emailed_status).to eq(Invite.emailed_status_types[:sending])
      expect(Jobs::InviteEmail.jobs.size).to eq(1)
      expect(Jobs::ProcessBulkInviteEmails.jobs.size).to eq(1)
    end
  end
end
