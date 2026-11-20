# frozen_string_literal: true

RSpec.describe Jobs::ProcessBulkInviteEmails do
  describe "#execute" do
    it "processes pending invites" do
      invite = Fabricate(:invite, emailed_status: Invite.emailed_status_types[:bulk_pending])

      described_class.new.execute({})

      invite.reload
      expect(invite.emailed_status).to eq(Invite.emailed_status_types[:sending])
      expect(Jobs::InviteEmail.jobs.size).to eq(1)
      expect(Jobs::ProcessBulkInviteEmails.jobs.size).to eq(1)
    end

    it "selects topic invitation emails for pending invites with a topic" do
      topic_invite = Fabricate(:invite, emailed_status: Invite.emailed_status_types[:bulk_pending])
      topic_invite.topics << Fabricate(:topic)
      forum_invite = Fabricate(:invite, emailed_status: Invite.emailed_status_types[:bulk_pending])

      described_class.new.execute({})

      expect(Jobs::InviteEmail.jobs.map { |job| job["args"].first }).to contain_exactly(
        hash_including("invite_id" => topic_invite.id, "invite_to_topic" => true),
        hash_including("invite_id" => forum_invite.id, "invite_to_topic" => false),
      )
    end
  end
end
