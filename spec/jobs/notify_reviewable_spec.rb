# frozen_string_literal: true

RSpec.describe Jobs::NotifyReviewable do
  # remove all the legacy stuff here when redesigned_user_menu_enabled is
  # removed
  describe '#execute' do
    fab!(:legacy_menu_admin) { Fabricate(:admin, moderator: true) }
    fab!(:legacy_menu_mod) { Fabricate(:moderator) }
    fab!(:group_user) { Fabricate(:group_user) }
    fab!(:legacy_menu_user) { group_user.user }

    fab!(:group) { group_user.group }

    fab!(:new_menu_admin) { Fabricate(:admin, moderator: true) }
    fab!(:new_menu_mod) { Fabricate(:moderator) }
    fab!(:new_menu_user) { Fabricate(:user, groups: [group]) }

    before do
      [new_menu_admin, new_menu_mod, new_menu_user].each(&:enable_redesigned_user_menu)
    end

    after do
      [new_menu_admin, new_menu_mod, new_menu_user].each(&:disable_redesigned_user_menu)
    end

    it "will notify users of new reviewable content and respects backward compatibility for the legacy user menu" do
      SiteSetting.enable_category_group_moderation = true

      GroupUser.create!(group_id: group.id, user_id: legacy_menu_mod.id)

      # Content for admins only
      admin_reviewable = Fabricate(:reviewable, reviewable_by_moderator: false)
      new_menu_admin.update!(last_seen_reviewable_id: admin_reviewable.id)
      messages = MessageBus.track_publish do
        described_class.new.execute(reviewable_id: admin_reviewable.id)
      end
      expect(messages.size).to eq(2)
      legacy_menu_admin_msg = messages.find { |m| m.user_ids.include?(legacy_menu_admin.id) }
      expect(legacy_menu_admin_msg.data[:reviewable_count]).to eq(1)
      expect(legacy_menu_admin_msg.channel).to eq("/reviewable_counts")
      expect(legacy_menu_admin_msg.data.key?(:unseen_reviewable_count)).to eq(false)

      new_menu_admin_msg = messages.find { |m| m.user_ids == [new_menu_admin.id] }
      expect(new_menu_admin_msg.data[:reviewable_count]).to eq(1)
      expect(new_menu_admin_msg.channel).to eq("/reviewable_counts/#{new_menu_admin.id}")
      expect(new_menu_admin_msg.data[:unseen_reviewable_count]).to eq(0)

      expect(messages.any? { |m| m.user_ids.include?(legacy_menu_mod.id) }).to eq(false)
      expect(messages.any? { |m| m.user_ids.include?(legacy_menu_user.id) }).to eq(false)
      expect(messages.any? { |m| m.user_ids.include?(new_menu_mod.id) }).to eq(false)
      expect(messages.any? { |m| m.user_ids.include?(new_menu_user.id) }).to eq(false)

      # Content for moderators
      mod_reviewable = Fabricate(:reviewable, reviewable_by_moderator: true)
      messages = MessageBus.track_publish do
        described_class.new.execute(reviewable_id: mod_reviewable.id)
      end
      expect(messages.size).to eq(4)
      legacy_menu_admin_msg = messages.find { |m| m.user_ids == [legacy_menu_admin.id] }
      expect(legacy_menu_admin_msg.data[:reviewable_count]).to eq(2)
      expect(legacy_menu_admin_msg.channel).to eq("/reviewable_counts")
      expect(legacy_menu_admin_msg.data.key?(:unseen_reviewable_count)).to eq(false)

      new_menu_admin_msg = messages.find { |m| m.user_ids == [new_menu_admin.id] }
      expect(new_menu_admin_msg.data[:reviewable_count]).to eq(2)
      expect(new_menu_admin_msg.channel).to eq("/reviewable_counts/#{new_menu_admin.id}")
      expect(new_menu_admin_msg.data[:unseen_reviewable_count]).to eq(1)

      legacy_menu_mod_msg = messages.find { |m| m.user_ids == [legacy_menu_mod.id] }
      expect(legacy_menu_mod_msg.data[:reviewable_count]).to eq(1)
      expect(legacy_menu_mod_msg.channel).to eq("/reviewable_counts")
      expect(legacy_menu_mod_msg.data.key?(:unseen_reviewable_count)).to eq(false)

      new_menu_mod_msg = messages.find { |m| m.user_ids == [new_menu_mod.id] }
      expect(new_menu_mod_msg.data[:reviewable_count]).to eq(1)
      expect(new_menu_mod_msg.channel).to eq("/reviewable_counts/#{new_menu_mod.id}")
      expect(new_menu_mod_msg.data[:unseen_reviewable_count]).to eq(1)

      expect(messages.any? { |m| m.user_ids.include?(legacy_menu_user.id) }).to eq(false)
      expect(messages.any? { |m| m.user_ids.include?(new_menu_user.id) }).to eq(false)

      new_menu_mod.update!(last_seen_reviewable_id: mod_reviewable.id)

      # Content for a group
      group_reviewable = Fabricate(:reviewable, reviewable_by_moderator: true, reviewable_by_group: group)
      messages = MessageBus.track_publish do
        described_class.new.execute(reviewable_id: group_reviewable.id)
      end
      expect(messages.size).to eq(6)
      legacy_menu_admin_msg = messages.find { |m| m.user_ids == [legacy_menu_admin.id] }
      expect(legacy_menu_admin_msg.data[:reviewable_count]).to eq(3)
      expect(legacy_menu_admin_msg.channel).to eq("/reviewable_counts")
      expect(legacy_menu_admin_msg.data.key?(:unseen_reviewable_count)).to eq(false)

      new_menu_admin_msg = messages.find { |m| m.user_ids == [new_menu_admin.id] }
      expect(new_menu_admin_msg.data[:reviewable_count]).to eq(3)
      expect(new_menu_admin_msg.channel).to eq("/reviewable_counts/#{new_menu_admin.id}")
      expect(new_menu_admin_msg.data[:unseen_reviewable_count]).to eq(2)

      legacy_menu_mod_msg = messages.find { |m| m.user_ids == [legacy_menu_mod.id] }
      expect(legacy_menu_mod_msg.data[:reviewable_count]).to eq(2)
      expect(legacy_menu_mod_msg.channel).to eq("/reviewable_counts")
      expect(legacy_menu_mod_msg.data.key?(:unseen_reviewable_count)).to eq(false)

      new_menu_mod_msg = messages.find { |m| m.user_ids == [new_menu_mod.id] }
      expect(new_menu_mod_msg.data[:reviewable_count]).to eq(2)
      expect(new_menu_mod_msg.channel).to eq("/reviewable_counts/#{new_menu_mod.id}")
      expect(new_menu_mod_msg.data[:unseen_reviewable_count]).to eq(1)

      legacy_menu_user_msg = messages.find { |m| m.user_ids == [legacy_menu_user.id] }
      expect(legacy_menu_user_msg.data[:reviewable_count]).to eq(1)
      expect(legacy_menu_user_msg.channel).to eq("/reviewable_counts")
      expect(legacy_menu_user_msg.data.key?(:unseen_reviewable_count)).to eq(false)

      new_menu_user_msg = messages.find { |m| m.user_ids == [new_menu_user.id] }
      expect(new_menu_user_msg.data[:reviewable_count]).to eq(1)
      expect(new_menu_user_msg.channel).to eq("/reviewable_counts/#{new_menu_user.id}")
      expect(new_menu_user_msg.data[:unseen_reviewable_count]).to eq(1)
    end

    it "won't notify a group when disabled" do
      SiteSetting.enable_category_group_moderation = false

      GroupUser.create!(group_id: group.id, user_id: legacy_menu_mod.id)
      GroupUser.create!(group_id: group.id, user_id: new_menu_mod.id)
      r3 = Fabricate(:reviewable, reviewable_by_moderator: true, reviewable_by_group: group)
      messages = MessageBus.track_publish("/reviewable_counts") do
        described_class.new.execute(reviewable_id: r3.id)
      end
      group_msg = messages.find { |m| m.user_ids.include?(legacy_menu_user.id) }
      expect(group_msg).to be_blank
      group_msg = messages.find { |m| m.user_ids.include?(new_menu_user.id) }
      expect(group_msg).to be_blank
    end

    it "respects priority" do
      SiteSetting.enable_category_group_moderation = true
      Reviewable.set_priorities(medium: 2.0)
      SiteSetting.reviewable_default_visibility = 'medium'

      GroupUser.create!(group_id: group.id, user_id: legacy_menu_mod.id)

      # Content for admins only
      r1 = Fabricate(:reviewable, reviewable_by_moderator: false)
      messages = MessageBus.track_publish("/reviewable_counts") do
        described_class.new.execute(reviewable_id: r1.id)
      end
      legacy_menu_admin_msg = messages.find { |m| m.user_ids.include?(legacy_menu_admin.id) }
      expect(legacy_menu_admin_msg.data[:reviewable_count]).to eq(0)

      # Content for moderators
      r2 = Fabricate(:reviewable, reviewable_by_moderator: true)
      messages = MessageBus.track_publish("/reviewable_counts") do
        described_class.new.execute(reviewable_id: r2.id)
      end
      legacy_menu_admin_msg = messages.find { |m| m.user_ids.include?(legacy_menu_admin.id) }
      expect(legacy_menu_admin_msg.data[:reviewable_count]).to eq(0)
      legacy_menu_mod_msg = messages.find { |m| m.user_ids.include?(legacy_menu_mod.id) }
      expect(legacy_menu_mod_msg.data[:reviewable_count]).to eq(0)

      # Content for a group
      r3 = Fabricate(:reviewable, reviewable_by_moderator: true, reviewable_by_group: group)
      messages = MessageBus.track_publish("/reviewable_counts") do
        described_class.new.execute(reviewable_id: r3.id)
      end
      legacy_menu_admin_msg = messages.find { |m| m.user_ids.include?(legacy_menu_admin.id) }
      expect(legacy_menu_admin_msg.data[:reviewable_count]).to eq(0)
      mod_messages = messages.select { |m| m.user_ids.include?(legacy_menu_mod.id) }
      expect(mod_messages.size).to eq(1)
      expect(mod_messages[0].data[:reviewable_count]).to eq(0)
      group_msg = messages.find { |m| m.user_ids.include?(legacy_menu_user.id) }
      expect(group_msg.data[:reviewable_count]).to eq(0)
    end
  end

  it 'skips sending notifications if user_ids is empty' do
    reviewable = Fabricate(:reviewable, reviewable_by_moderator: true)
    regular_user = Fabricate(:user)

    messages = MessageBus.track_publish("/reviewable_counts") do
      described_class.new.execute(reviewable_id: reviewable.id)
    end

    expect(messages.size).to eq(0)
  end
end
