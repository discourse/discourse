# frozen_string_literal: true

RSpec.describe Guardian, "#can_remove_allowed_users?" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:another_user, :user)
  fab!(:member, :user)
  fab!(:owner, :user)
  fab!(:moderator) { Fabricate(:moderator, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:anonymous_user, :anonymous)
  fab!(:staff_post) { Fabricate(:post, user: moderator) }
  fab!(:group)
  fab!(:another_group, :group)
  fab!(:automatic_group) { Fabricate(:group, automatic: true) }
  fab!(:plain_category, :category)

  fab!(:trust_level_0)
  fab!(:trust_level_1)
  fab!(:trust_level_2)
  fab!(:trust_level_3)
  fab!(:trust_level_4) { Fabricate(:trust_level_4, refresh_auto_groups: true) }
  fab!(:another_admin, :admin)
  fab!(:coding_horror) { Fabricate(:coding_horror, refresh_auto_groups: true) }

  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:post) { Fabricate(:post, topic: topic, user: topic.user) }

  before { Guardian.enable_topic_can_see_consistency_check }

  after { Guardian.disable_topic_can_see_consistency_check }

  context "with staff users" do
    it "is true" do
      expect(Guardian.new(moderator).can_remove_allowed_users?(topic)).to eq(true)
    end
  end

  context "with trust_level >= 2 user" do
    fab!(:topic_creator) { Fabricate(:user, trust_level: 2) }
    fab!(:topic) { Fabricate(:topic, user: topic_creator) }

    before do
      topic.allowed_users << topic_creator
      topic.allowed_users << another_user
    end

    it "is true" do
      expect(Guardian.new(topic_creator).can_remove_allowed_users?(topic)).to eq(true)
    end
  end

  context "with normal user" do
    fab!(:topic) { Fabricate(:topic, user: Fabricate(:user, trust_level: 1)) }

    before do
      topic.allowed_users << user
      topic.allowed_users << another_user
    end

    it "is false" do
      expect(Guardian.new(user).can_remove_allowed_users?(topic)).to eq(false)
    end

    describe "target_user is the user" do
      describe "when user is in a pm with another user" do
        it "returns true" do
          expect(Guardian.new(user).can_remove_allowed_users?(topic, user)).to eq(true)
        end
      end

      describe "when user is the creator of the topic" do
        it "returns false" do
          expect(Guardian.new(topic.user).can_remove_allowed_users?(topic, topic.user)).to eq(false)
        end
      end

      describe "when user is the only user in the topic" do
        it "returns false" do
          topic.remove_allowed_user(Discourse.system_user, another_user.username)

          expect(Guardian.new(user).can_remove_allowed_users?(topic, user)).to eq(false)
        end
      end
    end

    describe "target_user is not the user" do
      it "returns false" do
        expect(Guardian.new(user).can_remove_allowed_users?(topic, moderator)).to eq(false)
      end
    end
  end

  context "with anonymous users" do
    fab!(:topic)

    it "is false" do
      expect(Guardian.new.can_remove_allowed_users?(topic)).to eq(false)
    end

    it "is false when the topic does not have a user (for example because the user was removed)" do
      DB.exec("UPDATE topics SET user_id=NULL WHERE id=#{topic.id}")
      topic.reload

      expect(Guardian.new.can_remove_allowed_users?(topic)).to eq(false)
    end
  end
end
