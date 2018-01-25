require 'rails_helper'

describe Jobs::BulkInvite do

  context '.execute' do

    it 'raises an error when the filename is missing' do
      user = Fabricate(:user)
      expect { Jobs::BulkInvite.new.execute(current_user_id: user.id) }.to raise_error(Discourse::InvalidParameters)
    end

    context '.read_csv_file' do
      let(:user) { Fabricate(:user) }
      let(:bulk_invite) { Jobs::BulkInvite.new }
      let(:csv_file) { "#{Rails.root}/spec/fixtures/csv/discourse.csv" }

      it 'reads csv file' do
        bulk_invite.current_user = user
        bulk_invite.read_csv_file(csv_file)
        expect(Invite.where(email: "robin@outlook.com").exists?).to eq(true)
        expect(Invite.where(email: "jeff@gmail.com").exists?).to eq(true) # handles BOM
      end
    end

    context '.send_invite' do
      let(:bulk_invite) { Jobs::BulkInvite.new }
      let(:user) { Fabricate(:user) }
      let(:group) { Fabricate(:group) }
      let(:topic) { Fabricate(:topic) }
      let(:email) { "evil@trout.com" }
      let(:csv_info) { [] }

      it 'creates an invite' do
        csv_info[0] = email

        bulk_invite.current_user = user
        bulk_invite.send_invite(csv_info, 1)
        expect(Invite.where(email: email).exists?).to eq(true)
      end

      it 'creates an invite with group' do
        csv_info[0] = email
        csv_info[1] = group.name

        bulk_invite.current_user = user
        bulk_invite.send_invite(csv_info, 1)
        invite = Invite.where(email: email).first
        expect(invite).to be_present
        expect(InvitedGroup.where(invite_id: invite.id, group_id: group.id).exists?).to eq(true)
      end

      it 'creates an invite with topic' do
        csv_info[0] = email
        csv_info[2] = topic

        bulk_invite.current_user = user
        bulk_invite.send_invite(csv_info, 1)
        invite = Invite.where(email: email).first
        expect(invite).to be_present
        expect(TopicInvite.where(invite_id: invite.id, topic_id: topic.id).exists?).to eq(true)
      end

      it 'creates an invite with group and topic' do
        csv_info[0] = email
        csv_info[1] = group.name
        csv_info[2] = topic

        bulk_invite.current_user = user
        bulk_invite.send_invite(csv_info, 1)
        invite = Invite.where(email: email).first
        expect(invite).to be_present
        expect(InvitedGroup.where(invite_id: invite.id, group_id: group.id).exists?).to eq(true)
        expect(TopicInvite.where(invite_id: invite.id, topic_id: topic.id).exists?).to eq(true)
      end

    end

  end

end
