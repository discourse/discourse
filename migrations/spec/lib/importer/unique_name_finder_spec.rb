# frozen_string_literal: true

RSpec.describe Migrations::Importer::UniqueNameFinder do
  fab!(:admin)

  let(:usernames) { Set.new }
  let(:group_names) { Set.new }
  let(:shared_data) do
    instance_double(Migrations::Importer::SharedData).tap do |sd|
      allow(sd).to receive(:load).with(:usernames).and_return(usernames)
      allow(sd).to receive(:load).with(:group_names).and_return(group_names)
    end
  end
  let(:finder) { described_class.new(shared_data) }

  before do
    SiteSetting.reserved_usernames = "admin|moderator|system*|test_*"
    SiteSetting.here_mention = "here"
  end

  describe "#find_available_username" do
    it "returns the username when available" do
      username = finder.find_available_username("john_doe")
      expect(username).to eq("john_doe")
    end

    it "sanitizes the username" do
      username = finder.find_available_username("John Doe!")
      expect(username).to eq("John_Doe")
    end

    it "truncates long usernames" do
      long_name = "a" * 70
      username = finder.find_available_username(long_name)
      expect(username.length).to be <= 60
    end

    it "uses fallback username for blank input" do
      username = finder.find_available_username("")
      expect(username).to eq(I18n.t("fallback_username"))
    end

    it "marks username as used" do
      finder.find_available_username("john")
      expect(finder.find_available_username("john")).not_to eq("john")
    end

    it "handles case-insensitive duplicates" do
      finder.find_available_username("JohnDoe")
      username = finder.find_available_username("johndoe")
      expect(username).not_to eq("johndoe")
    end

    context "with reserved usernames" do
      it "avoids exact reserved usernames" do
        username = finder.find_available_username("admin")
        expect(username).not_to eq("admin")
      end

      it "avoids wildcard reserved usernames" do
        username = finder.find_available_username("system_user")
        expect(username).not_to eq("system_user")
      end

      it "avoids here mention" do
        username = finder.find_available_username("here")
        expect(username).not_to eq("here")
      end

      it "allows reserved usernames when explicitly permitted" do
        username = finder.find_available_username("admin", allow_reserved_username: true)
        expect(username).to eq("admin")
      end
    end

    it "handles Unicode normalization" do
      SiteSetting.reserved_usernames = "café"
      finder = described_class.new(shared_data)
      username = finder.find_available_username("café")
      expect(username).not_to eq("café")
    end
  end

  describe "#find_available_group_name" do
    it "returns the group name when available" do
      group_name = finder.find_available_group_name("developers")
      expect(group_name).to eq("developers")
    end

    it "sanitizes the group name" do
      group_name = finder.find_available_group_name("Dev Team!")
      expect(group_name).to eq("Dev_Team")
    end

    it "truncates long group names" do
      long_name = "a" * 70
      group_name = finder.find_available_group_name(long_name)
      expect(group_name.length).to be <= 60
    end

    it "uses fallback group name for blank input" do
      group_name = finder.find_available_group_name("")
      expect(group_name).to eq("group")
    end

    it "marks group name as used" do
      finder.find_available_group_name("developers")
      group_name = finder.find_available_group_name("developers")
      expect(group_name).not_to eq("developers")
    end

    it "prevents conflicts between usernames and group names" do
      finder.find_available_username("team")
      group_name = finder.find_available_group_name("team")
      expect(group_name).not_to eq("team")
    end
  end

  describe "persistence across instances" do
    it "shares used usernames via shared_data" do
      finder1 = described_class.new(shared_data)
      finder1.find_available_username("john")

      finder2 = described_class.new(shared_data)
      username = finder2.find_available_username("john")
      expect(username).not_to eq("john")
    end

    it "shares used group names via shared_data" do
      finder1 = described_class.new(shared_data)
      finder1.find_available_group_name("admins")

      finder2 = described_class.new(shared_data)
      group_name = finder2.find_available_group_name("admins")
      expect(group_name).not_to eq("admins")
    end
  end

  describe "reserved username caching" do
    it "caches exact reserved usernames" do
      expect(finder.send(:reserved_username?, "admin")).to be true
      expect(finder.send(:reserved_username?, "moderator")).to be true
    end

    it "caches wildcard reserved patterns" do
      expect(finder.send(:reserved_username?, "system_admin")).to be true
      expect(finder.send(:reserved_username?, "test_user")).to be true
    end

    it "handles empty here mention" do
      SiteSetting.here_mention = ""
      finder = described_class.new(shared_data)
      expect(finder.send(:reserved_username?, "here")).to be false
    end
  end

  describe "with existing shared data" do
    let(:usernames) { Set.new(%w[existing_user another_user]) }
    let(:group_names) { Set.new(["existing_group"]) }

    it "avoids usernames already in shared_data" do
      username = finder.find_available_username("existing_user")
      expect(username).not_to eq("existing_user")
    end

    it "avoids group names already in shared_data" do
      group_name = finder.find_available_group_name("existing_group")
      expect(group_name).not_to eq("existing_group")
    end

    it "treats usernames as case-insensitive in shared_data" do
      usernames.add("testuser")
      username = finder.find_available_username("TestUser")
      expect(username).not_to eq("TestUser")
    end

    it "treats group names as case-insensitive in shared_data" do
      group_names.add("testgroup")
      group_name = finder.find_available_group_name("TestGroup")
      expect(group_name).not_to eq("TestGroup")
    end

    it "avoids conflicts between existing usernames and new group names" do
      usernames.add("team")
      group_name = finder.find_available_group_name("team")
      expect(group_name).not_to eq("team")
    end

    it "avoids conflicts between existing group names and new usernames" do
      group_names.add("admin")
      username = finder.find_available_username("admin", allow_reserved_username: true)
      expect(username).not_to eq("admin")
    end
  end
end
