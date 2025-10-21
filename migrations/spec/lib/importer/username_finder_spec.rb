# frozen_string_literal: true

RSpec.describe Migrations::Importer::UsernameFinder do
  subject(:finder) { described_class.new(shared_data) }

  let(:usernames) { Set.new }
  let(:group_names) { Set.new }
  let(:shared_data) do
    instance_double(Migrations::Importer::SharedData).tap do |sd|
      allow(sd).to receive(:load).with(:usernames).and_return(usernames)
      allow(sd).to receive(:load).with(:group_names).and_return(group_names)
    end
  end

  before do
    allow(SiteSetting).to receive(:mandatory_values).and_return({})
    SiteSetting.reserved_usernames = "admin|moderator|system*|test_*"
    SiteSetting.here_mention = "here"
  end

  describe "#find_available_name" do
    it "sanitizes usernames using UserNameSuggester" do
      username = finder.find_available_name("John Doe!")
      expect(username).to eq("John_Doe")
    end

    it "removes invalid trailing characters after truncation" do
      long_name = "a" * 59 + "."
      username = finder.find_available_name(long_name)
      expect(username.length).to eq(59)
      expect(username).not_to end_with(".")
    end

    context "with reserved usernames" do
      it "avoids exact reserved usernames" do
        username = finder.find_available_name("admin")
        expect(username).to eq("admin_1")
      end

      it "treats reserved usernames as case-insensitive" do
        username = finder.find_available_name("ADMIN")
        expect(username).to eq("ADMIN_1")
      end

      it "avoids wildcard reserved usernames" do
        username = finder.find_available_name("system_user")
        expect(username).to eq("user_1")
      end

      it "avoids wildcard reserved usernames with wildcard at the end" do
        SiteSetting.reserved_usernames = "*bar"
        finder = described_class.new(shared_data)
        username = finder.find_available_name("foobar")
        expect(username).to eq("foobar_1")
      end

      it "avoids wildcard reserved usernames with wildcard in the middle" do
        SiteSetting.reserved_usernames = "test_*_user"
        finder = described_class.new(shared_data)
        username = finder.find_available_name("test_foo_user")
        expect(username).to eq("test_foo_user_1")
      end

      it "avoids `here` mention" do
        username = finder.find_available_name("here")
        expect(username).to eq("here_1")
      end

      it "handles empty `here` mentions" do
        SiteSetting.here_mention = ""
        finder = described_class.new(shared_data)
        username = finder.find_available_name("here")
        expect(username).to eq("here")
      end

      it "uses fallback for wildcards ending with star when suffixes cannot help" do
        username = finder.find_available_name("test_foo")
        fallback = I18n.t("importer.fallback_names.user")
        expect(username).to eq("#{fallback}_1")
      end

      it "allows reserved usernames when explicitly permitted" do
        username = finder.find_available_name("admin", allow_reserved_username: true)
        expect(username).to eq("admin")
      end

      it "allows reserved wildcard usernames when explicitly permitted" do
        username = finder.find_available_name("system_user", allow_reserved_username: true)
        expect(username).to eq("system_user")
      end

      it "still checks group name conflicts when allowing reserved usernames" do
        group_names.add("admin")
        username = finder.find_available_name("admin", allow_reserved_username: true)
        expect(username).to eq("admin_1")
      end
    end

    context "with Unicode usernames enabled" do
      before { SiteSetting.unicode_usernames = true }

      it "removes invalid grapheme clusters during sanitization" do
        username = finder.find_available_name("user👨‍👩‍👧‍👦test")
        expect(username).to eq("user_test")
      end

      it "removes invalid trailing characters at grapheme boundaries" do
        username = finder.find_available_name("café" + "." * 60)
        expect(username).not_to end_with(".")
      end

      it "respects Unicode normalization for reserved usernames" do
        actual = "Löwe" # NFD
        expected = "Löwe" # NFC

        SiteSetting.reserved_usernames = expected
        finder = described_class.new(shared_data)

        username = finder.find_available_name(actual)
        expect(username).to eq("#{expected}_1")
      end
    end

    it "prevents conflicts between usernames and group names" do
      group_names.add("team")
      username = finder.find_available_name("team")
      expect(username).to eq("team_1")
    end

    it "treats conflicts with group names as case-insensitive" do
      group_names.add("testgroup")
      username = finder.find_available_name("TestGroup")
      expect(username).to eq("TestGroup_1")
    end
  end

  describe "fallback behavior" do
    it "uses user-specific fallback name from I18n" do
      username = finder.find_available_name("")
      fallback = I18n.t("importer.fallback_names.user")
      expect(username).to eq("#{fallback}_1")
    end
  end
end
