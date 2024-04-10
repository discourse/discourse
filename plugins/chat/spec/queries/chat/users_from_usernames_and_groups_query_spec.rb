# frozen_string_literal: true

describe Chat::UsersFromUsernamesAndGroupsQuery do
  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }
  fab!(:user3) { Fabricate(:user) }
  fab!(:user4) { Fabricate(:user) }
  fab!(:group1) { Fabricate(:public_group, users: [user1, user2]) }
  fab!(:group2) { Fabricate(:public_group, users: [user3]) }

  context "when searching by usernames" do
    it "returns users matching the usernames" do
      result = described_class.call(usernames: [user1.username, user4.username], groups: [])
      expect(result).to contain_exactly(user1, user4)
    end

    it "works with a number" do
      user = Fabricate(:user, username: 12_345_678)
      result = described_class.call(usernames: [12_345_678], groups: [])
      expect(result).to contain_exactly(user)
    end
  end

  context "when searching by groups" do
    it "returns users belonging to the specified groups" do
      result = described_class.call(usernames: [], groups: [group1.name])
      expect(result).to contain_exactly(user1, user2)
    end

    it "works with a number" do
      group = Fabricate(:public_group, users: [user1, user2], name: 12_345_678)
      result = described_class.call(usernames: [], groups: [12_345_678])
      expect(result).to contain_exactly(user1, user2)
    end
  end

  context "when searching by both usernames and groups" do
    it "returns a unique set of users matching either condition" do
      result = described_class.call(usernames: [user2.username], groups: [group2.name])
      expect(result).to contain_exactly(user2, user3)
    end
  end

  context "when no usernames or groups are provided" do
    it "returns an empty array" do
      result = described_class.call(usernames: [], groups: [])
      expect(result).to be_empty
    end
  end

  context "when user chat is disabled" do
    before { user1.user_option.update!(chat_enabled: false) }

    it "does not return users with chat disabled" do
      result = described_class.call(usernames: [], groups: [group1.name])
      expect(result).not_to include(user1)
      expect(result).to include(user2)
    end
  end

  context "when excluding specific user IDs" do
    it "does not return users with specified IDs" do
      result =
        described_class.call(
          usernames: [user4.username],
          groups: [group1.name, group2.name],
          excluded_user_ids: [user1.id, user3.id],
        )
      expect(result).not_to include(user1, user3)
      expect(result).to include(user2, user4)
    end
  end
end
