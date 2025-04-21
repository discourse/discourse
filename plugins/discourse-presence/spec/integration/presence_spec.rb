# frozen_string_literal: true

RSpec.describe "discourse-presence" do
  describe "PresenceChannel configuration" do
    fab!(:user)
    fab!(:user2) { Fabricate(:user) }
    fab!(:admin)

    fab!(:group) do
      group = Fabricate(:group)
      group.add(user)
      group
    end

    fab!(:category) { Fabricate(:private_category, group: group) }
    fab!(:private_topic) { Fabricate(:topic, category: category) }
    fab!(:public_topic) { Fabricate(:topic, first_post: Fabricate(:post)) }

    fab!(:private_message) { Fabricate(:private_message_topic, allowed_groups: [group]) }

    before { PresenceChannel.clear_all! }

    it "handles invalid topic IDs" do
      expect do PresenceChannel.new("/discourse-presence/reply/-999").config end.to raise_error(
        PresenceChannel::NotFound,
      )

      expect do PresenceChannel.new("/discourse-presence/reply/blah").config end.to raise_error(
        PresenceChannel::NotFound,
      )
    end

    it "handles deleted topics" do
      public_topic.trash!

      expect do
        PresenceChannel.new("/discourse-presence/reply/#{public_topic.id}").config
      end.to raise_error(PresenceChannel::NotFound)

      expect do
        PresenceChannel.new("/discourse-presence/whisper/#{public_topic.id}").config
      end.to raise_error(PresenceChannel::NotFound)

      expect do
        PresenceChannel.new("/discourse-presence/edit/#{public_topic.first_post.id}").config
      end.to raise_error(PresenceChannel::NotFound)
    end

    it "handles secure category permissions for reply" do
      c = PresenceChannel.new("/discourse-presence/reply/#{private_topic.id}")
      expect(c.can_view?(user_id: user.id)).to eq(true)
      expect(c.can_enter?(user_id: user.id)).to eq(true)

      group.remove(user)

      c = PresenceChannel.new("/discourse-presence/reply/#{private_topic.id}", use_cache: false)
      expect(c.can_view?(user_id: user.id)).to eq(false)
      expect(c.can_enter?(user_id: user.id)).to eq(false)
    end

    it "handles secure category permissions for edit" do
      p = Fabricate(:post, topic: private_topic, user: private_topic.user)
      c = PresenceChannel.new("/discourse-presence/edit/#{p.id}")
      expect(c.can_view?(user_id: user.id)).to eq(false)
      expect(c.can_view?(user_id: private_topic.user.id)).to eq(true)
    end

    it "handles category moderators for edit" do
      SiteSetting.edit_all_post_groups = nil
      p = Fabricate(:post, topic: private_topic, user: private_topic.user)

      c = PresenceChannel.new("/discourse-presence/edit/#{p.id}")
      expect(c.config.allowed_group_ids).to contain_exactly(Group::AUTO_GROUPS[:staff])

      SiteSetting.enable_category_group_moderation = true
      Fabricate(:category_moderation_group, category:, group:)

      c = PresenceChannel.new("/discourse-presence/edit/#{p.id}", use_cache: false)
      expect(c.config.allowed_group_ids).to contain_exactly(Group::AUTO_GROUPS[:staff], group.id)
    end

    it "adds edit_all_post_groups to the presence channel" do
      p = Fabricate(:post, topic: public_topic, user: user)
      g = Fabricate(:group)

      SiteSetting.edit_all_post_groups = "#{Group::AUTO_GROUPS[:trust_level_1]}|#{g.id}"

      c = PresenceChannel.new("/discourse-presence/edit/#{p.id}")
      expect(c.config.allowed_group_ids).to contain_exactly(
        Group::AUTO_GROUPS[:staff],
        Group::AUTO_GROUPS[:trust_level_1],
        g.id,
      )
    end

    it "handles permissions for a public topic" do
      c = PresenceChannel.new("/discourse-presence/reply/#{public_topic.id}")
      expect(c.config.public).to eq(false)
      expect(c.config.allowed_group_ids).to contain_exactly(::Group::AUTO_GROUPS[:trust_level_0])
    end

    it "handles permissions for secure category topics" do
      c = PresenceChannel.new("/discourse-presence/reply/#{private_topic.id}")
      expect(c.config.public).to eq(false)
      expect(c.config.allowed_group_ids).to contain_exactly(group.id, Group::AUTO_GROUPS[:admins])
      expect(c.config.allowed_user_ids).to eq(nil)
    end

    it "handles permissions for private messages" do
      c = PresenceChannel.new("/discourse-presence/reply/#{private_message.id}")
      expect(c.config.public).to eq(false)
      expect(c.config.allowed_group_ids).to contain_exactly(group.id, Group::AUTO_GROUPS[:staff])
      expect(c.config.allowed_user_ids).to contain_exactly(
        *private_message.topic_allowed_users.pluck(:user_id),
      )
    end

    it "handles permissions for whispers" do
      c = PresenceChannel.new("/discourse-presence/whisper/#{public_topic.id}")
      expect(c.config.public).to eq(false)
      expect(c.config.allowed_group_ids).to contain_exactly(
        *SiteSetting.whispers_allowed_groups_map,
      )
      expect(c.config.allowed_user_ids).to eq(nil)
    end

    it "correctly allows whisperers when editing whispers" do
      p = Fabricate(:whisper, topic: public_topic, user: admin)
      c = PresenceChannel.new("/discourse-presence/edit/#{p.id}")
      expect(c.config.public).to eq(false)
      expect(c.config.allowed_group_ids).to contain_exactly(
        Group::AUTO_GROUPS[:staff],
        *SiteSetting.whispers_allowed_groups_map,
      )
      expect(c.config.allowed_user_ids).to eq(nil)
    end

    it "only allows staff when editing a locked post" do
      p = Fabricate(:post, topic: public_topic, user: admin, locked_by_id: Discourse.system_user.id)
      c = PresenceChannel.new("/discourse-presence/edit/#{p.id}")
      expect(c.config.public).to eq(false)
      expect(c.config.allowed_group_ids).to contain_exactly(Group::AUTO_GROUPS[:staff])
      expect(c.config.allowed_user_ids).to eq(nil)
    end

    it "allows author, staff, TL4 when editing a public post" do
      p = Fabricate(:post, topic: public_topic, user: user)
      c = PresenceChannel.new("/discourse-presence/edit/#{p.id}")
      expect(c.config.public).to eq(false)
      expect(c.config.allowed_group_ids).to contain_exactly(
        Group::AUTO_GROUPS[:trust_level_4],
        Group::AUTO_GROUPS[:staff],
      )
      expect(c.config.allowed_user_ids).to contain_exactly(user.id)
    end

    it "follows the wiki edit allowed groups site setting" do
      p = Fabricate(:post, topic: public_topic, user: user, wiki: true)
      SiteSetting.edit_wiki_post_allowed_groups = Group::AUTO_GROUPS[:trust_level_3]

      c = PresenceChannel.new("/discourse-presence/edit/#{p.id}")
      expect(c.config.public).to eq(false)
      expect(c.config.allowed_group_ids).to include(Group::AUTO_GROUPS[:trust_level_3])
      expect(c.config.allowed_user_ids).to contain_exactly(user.id)
    end

    it "allows author and staff when editing a private message" do
      post = Fabricate(:post, topic: private_message, user: user)

      c = PresenceChannel.new("/discourse-presence/edit/#{post.id}")
      expect(c.config.public).to eq(false)
      expect(c.config.allowed_group_ids).to contain_exactly(Group::AUTO_GROUPS[:staff])
      expect(c.config.allowed_user_ids).to contain_exactly(user.id)
    end

    it "includes all message participants for PM wiki" do
      post = Fabricate(:post, topic: private_message, user: user, wiki: true)

      c = PresenceChannel.new("/discourse-presence/edit/#{post.id}")
      expect(c.config.public).to eq(false)
      expect(c.config.allowed_group_ids).to contain_exactly(
        Group::AUTO_GROUPS[:staff],
        *private_message.allowed_groups.pluck(:id),
      )
      expect(c.config.allowed_user_ids).to contain_exactly(
        user.id,
        *private_message.allowed_users.pluck(:id),
      )
    end
  end
end
