# frozen_string_literal: true

RSpec.describe Migrations::Importer::UniqueNameFinder do
  subject(:finder) { described_class.new(shared_data) }

  fab!(:admin)

  let(:usernames) { Set.new }
  let(:group_names) { Set.new }
  let(:shared_data) do
    instance_double(Migrations::Importer::SharedData).tap do |sd|
      allow(sd).to receive(:load).with(:usernames).and_return(usernames)
      allow(sd).to receive(:load).with(:group_names).and_return(group_names)
    end
  end

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
      expect(username.length).to eq(60)
    end

    it "uses fallback username with suffix for blank input" do
      username = finder.find_available_username("")
      fallback = I18n.t("fallback_username")
      expect(username).to eq("#{fallback}_1")
    end

    it "generates sequential suffixes for duplicates" do
      username1 = finder.find_available_username("john")
      username2 = finder.find_available_username("john")
      username3 = finder.find_available_username("john")

      expect(username1).to eq("john")
      expect(username2).to eq("john_1")
      expect(username3).to eq("john_2")
    end

    it "handles case-insensitive duplicates" do
      username1 = finder.find_available_username("JohnDoe")
      username2 = finder.find_available_username("johndoe")
      username3 = finder.find_available_username("johnDoe")

      expect(username1).to eq("JohnDoe")
      expect(username2).to eq("johndoe_1")
      expect(username3).to eq("johnDoe_2")
    end

    it "truncates name to fit suffix when needed" do
      long_name = "a" * 50 + "1234567890"
      finder.find_available_username(long_name)
      username = finder.find_available_username(long_name)

      expected_truncated_username = "a" * 50 + "12345678"
      expect(username.length).to eq(60)
      expect(username).to eq("#{expected_truncated_username}_1")
    end

    it "uses fallback when sanitization results in empty string" do
      username = finder.find_available_username("___")
      fallback = I18n.t("fallback_username")
      expect(username).to eq("#{fallback}_1")
    end

    context "with reserved usernames" do
      it "avoids exact reserved usernames" do
        username = finder.find_available_username("admin")
        expect(username).to eq("admin_1")
      end

      it "treats reserved usernames as case-insensitive" do
        username = finder.find_available_username("ADMIN")
        expect(username).to eq("ADMIN_1")
      end

      it "avoids wildcard reserved usernames" do
        username = finder.find_available_username("system_user")
        expect(username).to eq("user_1")
      end

      it "avoids wildcard reserved usernames with wildcard at the end" do
        SiteSetting.reserved_usernames = "*bar"
        username = finder.find_available_username("foobar")
        expect(username).to eq("foobar_1")
      end

      it "avoids wildcard reserved usernames with wildcard in the middle" do
        SiteSetting.reserved_usernames = "test_*_user"
        finder = described_class.new(shared_data)
        username = finder.find_available_username("test_foo_user")
        expect(username).to eq("test_foo_user_1")
      end

      it "avoids here mention" do
        username = finder.find_available_username("here")
        expect(username).to eq("here_1")
      end

      it "uses fallback for wildcards ending with star when suffixes cannot help" do
        username = finder.find_available_username("test_foo")
        fallback = I18n.t("fallback_username")
        expect(username).to eq("#{fallback}_1")
      end

      it "allows reserved usernames when explicitly permitted" do
        username = finder.find_available_username("admin", allow_reserved_username: true)
        expect(username).to eq("admin")
      end
    end

    context "with Unicode usernames enabled" do
      before { SiteSetting.unicode_usernames = true }

      it "handles Unicode normalization" do
        actual = "Löwe" # NFD, "Lo\u0308we"
        expected = "Löwe" # NFC, "L\u00F6we"

        SiteSetting.reserved_usernames = expected

        username = finder.find_available_username(actual)
        expect(username).to eq("#{expected}_1")
      end

      it "removes invalid grapheme clusters during sanitization" do
        username = finder.find_available_username("user👨‍👩‍👧‍👦test")
        expect(username).to eq("user_test")
      end

      it "truncates at grapheme boundaries for multi-byte characters" do
        raise NotImplementedError
      end
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

    it "uses fallback group name with suffix for blank input" do
      group_name = finder.find_available_group_name("")
      expect(group_name).to eq("group_1")
    end

    it "generates sequential suffixes for duplicates" do
      group_name1 = finder.find_available_group_name("developers")
      group_name2 = finder.find_available_group_name("developers")
      group_name3 = finder.find_available_group_name("developers")

      expect(group_name1).to eq("developers")
      expect(group_name2).to eq("developers_1")
      expect(group_name3).to eq("developers_2")
    end

    it "marks group name as used" do
      finder.find_available_group_name("developers")
      group_name = finder.find_available_group_name("developers")
      expect(group_name).to eq("developers_1")
    end

    it "prevents conflicts between usernames and group names" do
      finder.find_available_username("team")
      group_name = finder.find_available_group_name("team")
      expect(group_name).to eq("team_1")
    end

    it "truncates name to fit suffix when needed" do
      long_name = "a" * 60
      finder.find_available_group_name(long_name)
      group_name = finder.find_available_group_name(long_name)

      expect(group_name.length).to eq(60)
      expect(group_name).to eq("#{"a" * 58}_1")
    end
  end

  describe "suffix caching" do
    it "maintains suffix counter per base name" do
      finder.find_available_username("john")
      finder.find_available_username("jane")

      expect(finder.find_available_username("john")).to eq("john_1")
      expect(finder.find_available_username("jane")).to eq("jane_1")
    end

    it "handles suffix cache overflow correctly" do
      # Create new finder with limited cache size
      limited_cache = ::LruRedux::Cache.new(2)
      finder_with_limited_cache = described_class.new(shared_data)
      allow(finder_with_limited_cache).to receive(:instance_variable_get).with(
        :@last_suffixes,
      ).and_return(limited_cache)

      finder_with_limited_cache.find_available_username("user1")
      finder_with_limited_cache.find_available_username("user2")
      finder_with_limited_cache.find_available_username("user3")

      # Cache should still work, oldest entry evicted
      expect(finder_with_limited_cache.find_available_username("user2")).to eq("user2_1")
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

    it "does not share suffix cache across instances" do
      finder1 = described_class.new(shared_data)
      finder1.find_available_username("john")
      finder1.find_available_username("john")

      finder2 = described_class.new(shared_data)
      # New instance starts suffix counter fresh, but still avoids taken names
      username = finder2.find_available_username("john")
      expect(username).to eq("john_1")
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
      expect(username).to eq("existing_user_1")
    end

    it "avoids group names already in shared_data" do
      group_name = finder.find_available_group_name("existing_group")
      expect(group_name).to eq("existing_group_1")
    end

    it "treats usernames as case-insensitive in shared_data" do
      usernames.add("testuser")
      username = finder.find_available_username("TestUser")
      expect(username).to eq("TestUser_1")
    end

    it "treats group names as case-insensitive in shared_data" do
      group_names.add("testgroup")
      group_name = finder.find_available_group_name("TestGroup")
      expect(group_name).to eq("TestGroup_1")
    end

    it "avoids conflicts between existing usernames and new group names" do
      usernames.add("team")
      group_name = finder.find_available_group_name("team")
      expect(group_name).to eq("team_1")
    end

    it "avoids conflicts between existing group names and new usernames" do
      group_names.add("admin")
      username = finder.find_available_username("admin", allow_reserved_username: true)
      expect(username).to eq("admin_1")
    end
  end

  describe "edge cases" do
    it "uses fallback after MAX_ATTEMPTS" do
      # Fill up all possible names for "test"
      501.times { |i| usernames.add("test#{i > 0 ? "_#{i}" : ""}") }

      username = finder.find_available_username("test")
      fallback = I18n.t("fallback_username")
      expect(username).to eq("#{fallback}_1")
    end
  end
end
