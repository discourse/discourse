# frozen_string_literal: true

RSpec.describe GroupShowSerializer do
  fab!(:user) { Fabricate(:user) }
  fab!(:group) { Fabricate(:group) }

  context "with an admin user" do
    fab!(:user) { Fabricate(:admin) }
    fab!(:group) { Fabricate(:group, users: [user]) }

    it "should return the right attributes" do
      json = GroupShowSerializer.new(group, scope: Guardian.new(user)).as_json

      expect(json[:group_show][:is_group_owner]).to eq(nil)
      expect(json[:group_show][:is_group_user]).to eq(true)
    end
  end

  context "with a group owner" do
    before { group.add_owner(user) }

    it "should return the right attributes" do
      json = GroupShowSerializer.new(group, scope: Guardian.new(user)).as_json

      expect(json[:group_show][:is_group_owner]).to eq(true)
      expect(json[:group_show][:is_group_user]).to eq(true)
    end
  end

  describe "#mentionable" do
    fab!(:group) { Fabricate(:group, mentionable_level: Group::ALIAS_LEVELS[:everyone]) }

    it "should return the right value" do
      json = GroupShowSerializer.new(group, scope: Guardian.new).as_json

      expect(json[:group_show][:mentionable]).to eq(nil)

      json = GroupShowSerializer.new(group, scope: Guardian.new(user)).as_json

      expect(json[:group_show][:mentionable]).to eq(true)
    end
  end

  describe "#automatic_membership_email_domains" do
    fab!(:group) { Fabricate(:group, automatic_membership_email_domains: "ilovediscourse.com") }
    let(:admin_guardian) { Guardian.new(Fabricate(:admin)) }

    it "should include email domains for admin" do
      subject =
        described_class.new(group, scope: admin_guardian, root: false, owner_group_ids: [group.id])
      expect(subject.as_json[:automatic_membership_email_domains]).to eq("ilovediscourse.com")
    end

    it "should not include email domains for other users" do
      subject =
        described_class.new(group, scope: Guardian.new, root: false, owner_group_ids: [group.id])
      expect(subject.as_json[:automatic_membership_email_domains]).to eq(nil)
    end
  end

  describe "admin only fields" do
    subject(:serializer) { described_class.new(group, scope: guardian, root: false) }

    fab!(:group) { Fabricate(:group, email_username: "foo@bar.com", email_password: "pa$$w0rd") }

    context "for a user" do
      let(:guardian) { Guardian.new(Fabricate(:user)) }

      it "are not visible" do
        expect(serializer.as_json[:email_username]).to be_nil
        expect(serializer.as_json[:email_password]).to be_nil
      end
    end

    context "for an admin" do
      let(:guardian) { Guardian.new(Fabricate(:admin)) }

      it "are visible" do
        expect(serializer.as_json[:email_username]).to eq("foo@bar.com")
        expect(serializer.as_json[:email_password]).to eq("pa$$w0rd")
        expect(serializer.as_json[:message_count]).to eq(0)
      end
    end
  end

  describe "default notification settings" do
    subject(:serializer) { described_class.new(group, scope: guardian, root: false) }

    let(:category1) { Fabricate(:category) }
    let(:category2) { Fabricate(:category) }
    let(:tag1) { Fabricate(:tag) }
    let(:tag2) { Fabricate(:tag) }

    before do
      SiteSetting.tagging_enabled = true

      GroupCategoryNotificationDefault.create!(
        group: group,
        category: category1,
        notification_level: GroupCategoryNotificationDefault.notification_levels[:watching],
      )
      GroupCategoryNotificationDefault.create!(
        group: group,
        category: category2,
        notification_level: GroupCategoryNotificationDefault.notification_levels[:tracking],
      )
      GroupTagNotificationDefault.create!(
        group: group,
        tag: tag1,
        notification_level: GroupTagNotificationDefault.notification_levels[:watching],
      )
      GroupTagNotificationDefault.create!(
        group: group,
        tag: tag2,
        notification_level: GroupTagNotificationDefault.notification_levels[:tracking],
      )
    end

    context "for a user" do
      let(:guardian) { Guardian.new(Fabricate(:user)) }

      it "are not visible" do
        expect(
          serializer.as_json.keys.select { |k| k.to_s.ends_with?("_category_ids") },
        ).to be_empty
        expect(serializer.as_json.keys.select { |k| k.to_s.ends_with?("_tags") }).to be_empty
      end
    end

    context "for admin" do
      let(:guardian) { Guardian.new(Fabricate(:admin)) }

      it "are correct" do
        expect(serializer.as_json[:watching_category_ids]).to eq([category1.id])
        expect(serializer.as_json[:tracking_category_ids]).to eq([category2.id])
        expect(serializer.as_json[:watching_first_post_category_ids]).to eq([])
        expect(serializer.as_json[:regular_category_ids]).to eq([])
        expect(serializer.as_json[:muted_category_ids]).to eq([])

        expect(serializer.as_json[:watching_tags]).to eq([tag1.name])
        expect(serializer.as_json[:tracking_tags]).to eq([tag2.name])
        expect(serializer.as_json[:watching_first_post_tags]).to eq([])
        expect(serializer.as_json[:regular_tags]).to eq([])
        expect(serializer.as_json[:muted_tags]).to eq([])
      end

      it "doesn't include tag fields if tags are disabled" do
        SiteSetting.tagging_enabled = false
        expect(
          serializer.as_json.keys.select { |k| k.to_s.ends_with?("_category_ids") }.length,
        ).to eq(5)
        expect(serializer.as_json.keys.select { |k| k.to_s.ends_with?("_tags") }).to be_empty
      end
    end
  end
end
