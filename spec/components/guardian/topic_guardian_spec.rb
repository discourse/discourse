# frozen_string_literal: true

require 'rails_helper'

describe TopicGuardian do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }
  fab!(:tl3_user) { Fabricate(:leader) }
  fab!(:moderator) { Fabricate(:moderator) }
  fab!(:category) { Fabricate(:category) }

  describe '#can_create_shared_draft?' do
    it 'when shared_drafts are disabled' do
      SiteSetting.shared_drafts_min_trust_level = 'admin'

      expect(Guardian.new(admin).can_create_shared_draft?).to eq(false)
    end

    it 'when user is a moderator and access is set to admin' do
      SiteSetting.shared_drafts_category = category.id
      SiteSetting.shared_drafts_min_trust_level = 'admin'

      expect(Guardian.new(moderator).can_create_shared_draft?).to eq(false)
    end

    it 'when user is a moderator and access is set to staff' do
      SiteSetting.shared_drafts_category = category.id
      SiteSetting.shared_drafts_min_trust_level = 'staff'

      expect(Guardian.new(moderator).can_create_shared_draft?).to eq(true)
    end

    it 'when user is TL3 and access is set to TL2' do
      SiteSetting.shared_drafts_category = category.id
      SiteSetting.shared_drafts_min_trust_level = '2'

      expect(Guardian.new(tl3_user).can_create_shared_draft?).to eq(true)
    end
  end

  describe '#can_see_shared_draft?' do
    it 'when shared_drafts are disabled (existing shared drafts)' do
      SiteSetting.shared_drafts_min_trust_level = 'admin'

      expect(Guardian.new(admin).can_see_shared_draft?).to eq(true)
    end

    it 'when user is a moderator and access is set to admin' do
      SiteSetting.shared_drafts_category = category.id
      SiteSetting.shared_drafts_min_trust_level = 'admin'

      expect(Guardian.new(moderator).can_see_shared_draft?).to eq(false)
    end

    it 'when user is a moderator and access is set to staff' do
      SiteSetting.shared_drafts_category = category.id
      SiteSetting.shared_drafts_min_trust_level = 'staff'

      expect(Guardian.new(moderator).can_see_shared_draft?).to eq(true)
    end

    it 'when user is TL3 and access is set to TL2' do
      SiteSetting.shared_drafts_category = category.id
      SiteSetting.shared_drafts_min_trust_level = '2'

      expect(Guardian.new(tl3_user).can_see_shared_draft?).to eq(true)
    end
  end

  describe '#can_edit_topic?' do
    context 'when the topic is a shared draft' do
      let(:tl2_user) { Fabricate(:user, trust_level: TrustLevel[2])  }

      before do
        SiteSetting.shared_drafts_category = category.id
        SiteSetting.shared_drafts_min_trust_level = '2'
      end

      it 'returns false if the topic is a PM' do
        pm_with_draft = Fabricate(:private_message_topic, category: category)
        Fabricate(:shared_draft, topic: pm_with_draft)

        expect(Guardian.new(tl2_user).can_edit_topic?(pm_with_draft)).to eq(false)
      end

      it 'returns false if the topic is archived' do
        archived_topic = Fabricate(:topic, archived: true, category: category)
        Fabricate(:shared_draft, topic: archived_topic)

        expect(Guardian.new(tl2_user).can_edit_topic?(archived_topic)).to eq(false)
      end

      it 'returns true if a shared draft exists' do
        topic = Fabricate(:topic, category: category)
        Fabricate(:shared_draft, topic: topic)

        expect(Guardian.new(tl2_user).can_edit_topic?(topic)).to eq(true)
      end

      it 'returns false if the user has a lower trust level' do
        tl1_user = Fabricate(:user, trust_level: TrustLevel[1])
        topic = Fabricate(:topic, category: category)
        Fabricate(:shared_draft, topic: topic)

        expect(Guardian.new(tl1_user).can_edit_topic?(topic)).to eq(false)
      end

      it 'returns true if the shared_draft is from a different category' do
        topic = Fabricate(:topic, category: Fabricate(:category))
        Fabricate(:shared_draft, topic: topic)

        expect(Guardian.new(tl2_user).can_edit_topic?(topic)).to eq(false)
      end
    end
  end

  describe '#can_review_topic?' do
    it 'returns false for TL4 users' do
      tl4_user = Fabricate(:user, trust_level: TrustLevel[4])
      topic = Fabricate(:topic)

      expect(Guardian.new(tl4_user).can_review_topic?(topic)).to eq(false)
    end
  end

  describe '#publish_read_state?' do
    fab!(:category) { Fabricate(:category, publish_read_state: true) }
    fab!(:topic) { Fabricate(:topic, category: category) }
    fab!(:post) { Fabricate(:post, topic: topic) }

    fab!(:group) do
      Fabricate(:group,
        messageable_level: Group::ALIAS_LEVELS[:everyone],
        publish_read_state: true
      ).tap { |g| g.add(user) }
    end

    fab!(:group_message) do
      create_post(
        user: user,
        target_group_names: [group.name],
        archetype: Archetype.private_message
      ).topic
    end

    it 'returns true for a valid topic' do
      SiteSetting.allow_publish_read_state_on_categories = true

      expect(Guardian.new(user).publish_read_state?(topic, user)).to eq(true)
    end

    it 'returns false if publish read state in category site setting has been disabled' do
      SiteSetting.allow_publish_read_state_on_categories = false

      expect(Guardian.new(user).publish_read_state?(topic, user)).to eq(false)
    end

    it 'returns false if category is not configured to publish read state' do
      category.update!(publish_read_state: false)

      expect(Guardian.new(user).publish_read_state?(topic, user)).to eq(false)
    end

    it 'returns false if group is not configured to publish read state' do
      group.update!(publish_read_state: false)

      expect(Guardian.new(user).publish_read_state?(group_message, user))
        .to eq(false)
    end

    it 'returns false if user does not have access to group message' do
      user_2 = Fabricate(:user)

      expect(Guardian.new(user_2).publish_read_state?(group_message, user_2))
        .to eq(false)
    end

    it 'returns true if group has been configured to publish read state' do
      expect(Guardian.new(user).publish_read_state?(group_message, user))
        .to eq(true)
    end
  end
end
