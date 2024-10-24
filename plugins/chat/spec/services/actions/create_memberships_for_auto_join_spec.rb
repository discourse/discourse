# frozen_string_literal: true

RSpec.describe Chat::Action::CreateMembershipsForAutoJoin do
  subject(:action) { described_class.call(channel:, params:) }

  fab!(:channel) { Fabricate(:chat_channel, auto_join_users: true) }
  fab!(:user_1) { Fabricate(:user, last_seen_at: 15.minutes.ago) }

  let(:start_user_id) { user_1.id }
  let(:end_user_id) { user_1.id }
  let(:params) { OpenStruct.new(start_user_id: start_user_id, end_user_id: end_user_id) }

  it "adds correct members" do
    expect(action).to eq([user_1.id])
  end

  it "sets the reason to automatic" do
    action
    expect(channel.membership_for(user_1)).to be_automatic
  end

  context "with others users not in the batch" do
    fab!(:user_2) { Fabricate(:user) }

    it "adds correct members" do
      expect(action).to eq([user_1.id])
    end
  end

  context "with suspended users" do
    before { user_1.update!(suspended_till: 1.year.from_now) }

    it "skips suspended users" do
      expect(action).to eq([])
    end
  end

  context "with users not seen recently" do
    before { user_1.update!(last_seen_at: 4.months.ago) }

    it "skips users last_seen more than 3 months ago" do
      expect(action).to eq([])
    end
  end

  context "with never seen users" do
    before { user_1.update!(last_seen_at: nil) }

    it "includes users with last_seen set to null" do
      expect(action).to eq([user_1.id])
    end
  end

  context "with disabled chat users" do
    before { user_1.user_option.update!(chat_enabled: false) }

    it "skips users without chat_enabled" do
      expect(action).to eq([])
    end
  end

  context "with anonymous users" do
    fab!(:user_1) { Fabricate(:anonymous, last_seen_at: 15.minutes.ago) }

    it "skips anonymous users" do
      expect(action).to eq([])
    end
  end

  context "with inactive users" do
    before { user_1.update!(active: false) }

    it "skips inactive users" do
      expect(action).to eq([])
    end
  end

  context "with staged users" do
    before { user_1.update!(staged: true) }

    it "skips staged users" do
      expect(action).to eq([])
    end
  end

  context "when user is already a member" do
    before { channel.add(user_1) }

    it "is a noop" do
      expect(action).to eq([])
    end
  end

  context "when category is restricted" do
    fab!(:user_1) { Fabricate(:user) }
    fab!(:user_2) { Fabricate(:user) }
    fab!(:group_1) { Fabricate(:group) }
    fab!(:channel) { Fabricate(:private_category_channel, group: group_1, auto_join_users: true) }

    let(:end_user_id) { user_2.id }

    before { group_1.add(user_1) }

    it "only joins users with access to the category through the group" do
      expect(action).to eq([user_1.id])
    end

    context "when the user has access through multiple groups" do
      fab!(:group_2) { Fabricate(:group) }

      before do
        channel.category.category_groups.create!(
          group_id: group_2.id,
          permission_type: CategoryGroup.permission_types[:full],
        )
        group_2.add(user_1)
      end

      it "correctly joins the user" do
        expect(action).to eq([user_1.id])
      end
    end

    context "when the category group is read only" do
      fab!(:channel) { Fabricate(:private_category_channel, auto_join_users: true) }

      before do
        channel.category.category_groups.create!(
          group_id: group_1.id,
          permission_type: CategoryGroup.permission_types[:readonly],
        )
        group_1.add(user_1)
      end

      it "doesn’t join the users of the group" do
        expect(action).to eq([])
      end
    end

    context "when the category group has create post permission" do
      fab!(:channel) { Fabricate(:private_category_channel, auto_join_users: true) }

      before do
        channel.category.category_groups.create!(
          group_id: group_1.id,
          permission_type: CategoryGroup.permission_types[:create_post],
        )
        group_1.add(user_1)
      end

      it "correctly joins the user" do
        expect(action).to eq([user_1.id])
      end
    end

    context "when user has allowed groups and disallowed groups" do
      fab!(:group_2) { Fabricate(:group) }

      before do
        channel.category.category_groups.create!(
          group_id: group_2.id,
          permission_type: CategoryGroup.permission_types[:readonly],
        )
        group_2.add(user_1)
      end

      it "correctly joins the user" do
        expect(action).to eq([user_1.id])
      end
    end
  end
end
