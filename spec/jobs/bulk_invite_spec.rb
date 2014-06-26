require 'spec_helper'

describe Jobs::BulkInvite do

  context '.execute' do

    it 'raises an error when the filename is missing' do
      lambda { Jobs::BulkInvite.new.execute(identifier: '46-discoursecsv', chunks: '1') }.should raise_error(Discourse::InvalidParameters)
    end

    it 'raises an error when the identifier is missing' do
      lambda { Jobs::BulkInvite.new.execute(filename: 'discourse.csv', chunks: '1') }.should raise_error(Discourse::InvalidParameters)
    end

    it 'raises an error when the chunks is missing' do
      lambda { Jobs::BulkInvite.new.execute(filename: 'discourse.csv', identifier: '46-discoursecsv') }.should raise_error(Discourse::InvalidParameters)
    end

    context '.read_csv_file' do
      let(:user) { Fabricate(:user) }
      let(:bulk_invite) { Jobs::BulkInvite.new }
      let(:csv_file) { File.new("#{Rails.root}/spec/fixtures/csv/discourse.csv") }

      it 'reads csv file' do
        bulk_invite.current_user = user
        bulk_invite.read_csv_file(csv_file)
        Invite.where(email: "robin@outlook.com").exists?.should be_true
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
        Invite.where(email: email).exists?.should be_true
      end

      it 'creates an invite with group' do
        csv_info[0] = email
        csv_info[1] = group.name

        bulk_invite.current_user = user
        bulk_invite.send_invite(csv_info, 1)
        invite = Invite.where(email: email).first
        invite.should be_present
        InvitedGroup.where(invite_id: invite.id, group_id: group.id).exists?.should be_true
      end

      it 'creates an invite with topic' do
        csv_info[0] = email
        csv_info[2] = topic

        bulk_invite.current_user = user
        bulk_invite.send_invite(csv_info, 1)
        invite = Invite.where(email: email).first
        invite.should be_present
        TopicInvite.where(invite_id: invite.id, topic_id: topic.id).exists?.should be_true
      end

      it 'creates an invite with group and topic' do
        csv_info[0] = email
        csv_info[1] = group.name
        csv_info[2] = topic

        bulk_invite.current_user = user
        bulk_invite.send_invite(csv_info, 1)
        invite = Invite.where(email: email).first
        invite.should be_present
        InvitedGroup.where(invite_id: invite.id, group_id: group.id).exists?.should be_true
        TopicInvite.where(invite_id: invite.id, topic_id: topic.id).exists?.should be_true
      end

    end

  end

end
