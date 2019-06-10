# frozen_string_literal: true

require 'rails_helper'

describe Jobs::BulkInvite do
  describe '#execute' do
    fab!(:user) { Fabricate(:user) }
    fab!(:admin) { Fabricate(:admin) }
    fab!(:group1) { Fabricate(:group, name: 'group1') }
    fab!(:group2) { Fabricate(:group, name: 'group2') }
    fab!(:topic) { Fabricate(:topic, id: 999) }
    let(:email) { "test@discourse.org" }
    let(:invites) { [{ email: 'test2@discourse.org' }, { email: 'test@discourse.org', groups: 'GROUP1;group2', topic_id: 999 }] }

    it 'raises an error when the invites array is missing' do
      expect { Jobs::BulkInvite.new.execute(current_user_id: user.id) }
        .to raise_error(Discourse::InvalidParameters, /invites/)
    end

    it 'raises an error when current_user_id is not valid' do
      expect { Jobs::BulkInvite.new.execute(invites: invites) }
        .to raise_error(Discourse::InvalidParameters, /current_user_id/)
    end

    it 'creates the right invites' do
      described_class.new.execute(
        current_user_id: admin.id,
        invites: invites
      )

      invite = Invite.last

      expect(invite.email).to eq(email)
      expect(Invite.exists?(email: "test2@discourse.org")).to eq(true)

      expect(invite.invited_groups.pluck(:group_id)).to contain_exactly(
        group1.id, group2.id
      )

      expect(invite.topic_invites.pluck(:topic_id)).to contain_exactly(topic.id)
    end

    it 'does not create invited groups for automatic groups' do
      group2.update!(automatic: true)

      described_class.new.execute(
        current_user_id: admin.id,
        invites: invites
      )

      invite = Invite.last

      expect(invite.email).to eq(email)

      expect(invite.invited_groups.pluck(:group_id)).to contain_exactly(
        group1.id
      )
    end

    it 'does not create invited groups record if the user can not manage the group' do
      group1.add_owner(user)

      described_class.new.execute(
        current_user_id: user.id,
        invites: invites
      )

      invite = Invite.last

      expect(invite.email).to eq(email)

      expect(invite.invited_groups.pluck(:group_id)).to contain_exactly(
        group1.id
      )
    end

    it 'adds existing users to valid groups' do
      existing_user = Fabricate(:user, email: "test@discourse.org")

      group2.update!(automatic: true)

      expect do
        described_class.new.execute(
          current_user_id: admin.id,
          invites: invites
        )
      end.to change { Invite.count }.by(1)

      expect(Invite.exists?(email: "test2@discourse.org")).to eq(true)
      expect(existing_user.reload.groups).to eq([group1])
    end
  end

end
