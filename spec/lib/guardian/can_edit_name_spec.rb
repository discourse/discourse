# frozen_string_literal: true

RSpec.describe Guardian, "#can_edit_name?" do
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

  it "is false without a logged in user" do
    expect(
      Guardian.new(nil).can_edit_name?(Fabricate(:user, created_at: 1.minute.ago)),
    ).to be_falsey
  end

  it "is false for regular users to edit another user's name" do
    expect(
      Guardian.new(Fabricate(:user)).can_edit_name?(Fabricate(:user, created_at: 1.minute.ago)),
    ).to be_falsey
  end

  context "for anonymous user" do
    before { SiteSetting.allow_anonymous_mode = true }

    it "is false" do
      expect(Guardian.new(anonymous_user).can_edit_name?(anonymous_user)).to be_falsey
    end
  end

  context "for a new user" do
    let(:target_user) { Fabricate(:user, created_at: 1.minute.ago) }

    it "is true for the user to change their own name" do
      expect(Guardian.new(target_user).can_edit_name?(target_user)).to be_truthy
    end

    it "is true for moderators" do
      expect(Guardian.new(moderator).can_edit_name?(user)).to be_truthy
    end

    it "is true for admins" do
      expect(Guardian.new(admin).can_edit_name?(user)).to be_truthy
    end
  end

  context "when name is disabled in preferences" do
    before { SiteSetting.enable_names = false }

    it "is false for the user to change their own name" do
      expect(Guardian.new(user).can_edit_name?(user)).to be_falsey
    end

    it "is false for moderators" do
      expect(Guardian.new(moderator).can_edit_name?(user)).to be_falsey
    end

    it "is true for admins" do
      expect(Guardian.new(admin).can_edit_name?(user)).to be_truthy
    end
  end

  context "when name is enabled in preferences" do
    before { SiteSetting.enable_names = true }

    context "when SSO is disabled" do
      before do
        SiteSetting.enable_discourse_connect = false
        SiteSetting.auth_overrides_name = false
      end

      it "is true for admins" do
        expect(Guardian.new(admin).can_edit_name?(admin)).to be_truthy
      end

      it "is true for moderators" do
        expect(Guardian.new(moderator).can_edit_name?(moderator)).to be_truthy
      end

      it "is true for users" do
        expect(Guardian.new(user).can_edit_name?(user)).to be_truthy
      end
    end

    context "when SSO is enabled" do
      before do
        SiteSetting.discourse_connect_url = "https://www.example.com/sso"
        SiteSetting.discourse_connect_secret = "x" * 10
        SiteSetting.enable_discourse_connect = true
      end

      context "when SSO name override is active" do
        before { SiteSetting.auth_overrides_name = true }

        it "is false for admins" do
          expect(Guardian.new(admin).can_edit_name?(admin)).to be_falsey
        end

        it "is false for moderators" do
          expect(Guardian.new(moderator).can_edit_name?(moderator)).to be_falsey
        end

        it "is false for users" do
          expect(Guardian.new(user).can_edit_name?(user)).to be_falsey
        end
      end

      context "when SSO name override is not active" do
        before { SiteSetting.auth_overrides_name = false }

        it "is true for admins" do
          expect(Guardian.new(admin).can_edit_name?(admin)).to be_truthy
        end

        it "is true for moderators" do
          expect(Guardian.new(moderator).can_edit_name?(moderator)).to be_truthy
        end

        it "is true for users" do
          expect(Guardian.new(user).can_edit_name?(user)).to be_truthy
        end
      end
    end
  end
end
