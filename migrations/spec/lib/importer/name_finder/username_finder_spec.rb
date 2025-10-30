# frozen_string_literal: true

RSpec.describe ::Migrations::Importer::UsernameFinder do
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
    context "with basic functionality" do
      it "returns the username when available" do
        username = finder.find_available_name("john_doe")
        expect(username).to eq("john_doe")
      end

      it "sanitizes usernames" do
        username = finder.find_available_name("John Doe!")
        expect(username).to eq("John_Doe")
      end

      it "uses fallback username with suffix for blank input" do
        username = finder.find_available_name("")
        fallback = I18n.t("importer.fallback_names.user")
        expect(username).to eq("#{fallback}_1")
      end

      it "uses fallback when sanitization results in empty string" do
        username = finder.find_available_name("___")
        fallback = I18n.t("importer.fallback_names.user")
        expect(username).to eq("#{fallback}_1")
      end
    end

    context "when truncating names" do
      it "truncates long usernames to max length" do
        long_name = "a" * 70
        username = finder.find_available_name(long_name)
        expect(username).to eq("a" * 60)
      end

      it "removes invalid trailing characters after truncation" do
        long_name = "a" * 58 + "_."
        username = finder.find_available_name(long_name)
        expect(username).to eq("a" * 58)
      end
    end

    context "when generating suffixes" do
      it "generates sequential suffixes for duplicates" do
        username1 = finder.find_available_name("john")
        username2 = finder.find_available_name("john")
        username3 = finder.find_available_name("john")
        11.times { finder.find_available_name("john") }
        username4 = finder.find_available_name("john")

        expect(username1).to eq("john")
        expect(username2).to eq("john_1")
        expect(username3).to eq("john_2")
        expect(username4).to eq("john_14")
      end

      it "handles case-insensitive duplicates" do
        username1 = finder.find_available_name("JohnDoe")
        username2 = finder.find_available_name("johndoe")
        username3 = finder.find_available_name("johnDoe")

        expect(username1).to eq("JohnDoe")
        expect(username2).to eq("johndoe_1")
        expect(username3).to eq("johnDoe_2")
      end

      it "truncates name to fit suffix when needed" do
        long_name = "a" * 50 + "1234567890"
        finder.find_available_name(long_name)
        username = finder.find_available_name(long_name)

        expected_truncated_username = "a" * 50 + "12345678"
        expect(username).to eq("#{expected_truncated_username}_1")
      end

      it "truncates further when suffix length increases" do
        long_name = "a" * 50 + "1234567890"

        9.times { finder.find_available_name(long_name) }

        username = finder.find_available_name(long_name)
        expect(username).to eq("#{long_name[0, 58]}_9")

        # Suffix increases to _10, requires more truncation
        username = finder.find_available_name(long_name)
        expect(username).to eq("#{long_name[0, 57]}_1")

        # Continue with 57-char base through _99
        97.times { finder.find_available_name(long_name) }
        username = finder.find_available_name(long_name)
        expect(username).to eq("#{long_name[0, 57]}_99")

        # Suffix increases to _100, requires more truncation
        username = finder.find_available_name(long_name)
        expect(username).to eq("#{long_name[0, 56]}_1")
      end
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

      it "avoids reserved usernames with wildcard at the end" do
        username = finder.find_available_name("system_user")
        expect(username).to eq("user_1")
      end

      it "avoids reserved usernames with wildcard at start" do
        SiteSetting.reserved_usernames = "*bar"
        finder = described_class.new(shared_data)
        username = finder.find_available_name("foobar")
        expect(username).to eq("foobar_1")
      end

      it "avoids wildcard reserved usernames with star in middle" do
        SiteSetting.reserved_usernames = "test_*_user"
        finder = described_class.new(shared_data)
        username = finder.find_available_name("test_foo_user")
        expect(username).to eq("test_foo_user_1")
      end

      it "avoids `here` mention" do
        username = finder.find_available_name("here")
        expect(username).to eq("here_1")
      end

      it "handles empty `here` mention" do
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

      it "handles Unicode normalization in reserved usernames" do
        actual = "Löwe" # NFD
        expected = "Löwe" # NFC

        SiteSetting.reserved_usernames = expected
        finder = described_class.new(shared_data)

        username = finder.find_available_name(actual)
        expect(username).to eq("#{expected}_1")
      end

      it "removes invalid grapheme clusters during sanitization" do
        username = finder.find_available_name("user👨‍👩‍👧‍👦test")
        expect(username).to eq("user_test")
      end

      it "truncates at grapheme boundaries for multi-byte characters" do
        # 94 characters, 67 grapheme clusters
        long_name =
          "बग_उत्पादन_और_पेशेवर_कॉफी_उपभोग_सेवा_प्रभाग_के_विभाग_के_मुख्य_अभियंता_सर्वोच्च_कमांडर_महोदय_जी"

        # 60 characters, 43 grapheme clusters
        username = finder.find_available_name(long_name)
        expect(username).to eq("बग_उत्पादन_और_पेशेवर_कॉफी_उपभोग_सेवा_प्रभाग_के_विभाग_के_मुख्")

        # 60 characters, 42 original grapheme clusters plus suffix
        username = finder.find_available_name(long_name)
        expect(username).to eq("बग_उत्पादन_और_पेशेवर_कॉफी_उपभोग_सेवा_प्रभाग_के_विभाग_के_मु_1")
        8.times { finder.find_available_name(long_name) }

        # 58 characters, 41 original grapheme clusters plus suffix
        username = finder.find_available_name(long_name)
        expect(username).to eq("बग_उत्पादन_और_पेशेवर_कॉफी_उपभोग_सेवा_प्रभाग_के_विभाग_के_1")
      end
    end

    context "with group name conflicts" do
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

    context "when persisting across instances" do
      it "shares used usernames via shared_data" do
        finder1 = described_class.new(shared_data)
        finder1.find_available_name("john")

        finder2 = described_class.new(shared_data)
        username = finder2.find_available_name("john")
        expect(username).to eq("john_1")
      end
    end

    context "with existing shared data" do
      let(:usernames) { Set.new(%w[existing_user another_user]) }

      it "avoids usernames already in shared_data" do
        username = finder.find_available_name("existing_user")
        expect(username).to eq("existing_user_1")
      end
    end

    context "when extracting suffixes from existing names" do
      it "extracts max suffix from dense sequences" do
        usernames.add("foo")
        2000.times { |i| usernames.add("foo_#{i + 1}") }

        username = finder.find_available_name("foo")
        expect(username).to eq("foo_2001")
      end

      it "handles sparse sequences efficiently" do
        usernames.add("foo")
        usernames.add("foo_5")
        usernames.add("foo_1000")

        username = finder.find_available_name("foo")
        expect(username).to eq("foo_6")
      end
    end

    context "when ensuring minimum length" do
      subject(:finder) { described_class.new(shared_data, min_length: 5) }

      it "pads suffix with leading zeros for short names" do
        username1 = finder.find_available_name("ab")
        username2 = finder.find_available_name("ab")
        username3 = finder.find_available_name("ab")
        8.times { finder.find_available_name("ab") }
        username4 = finder.find_available_name("ab")

        expect(username1).to eq("ab_01")
        expect(username2).to eq("ab_02")
        expect(username3).to eq("ab_03")
        expect(username4).to eq("ab_12")
      end

      it "stops padding when suffix grows to fill minimum length" do
        username = finder.find_available_name("a")
        expect(username).to eq("a_001")

        98.times { finder.find_available_name("a") }
        username = finder.find_available_name("a")
        expect(username).to eq("a_100")
      end
    end

    context "with fallback name conflicts" do
      it "finds next available fallback name when some are already used" do
        fallback = I18n.t("importer.fallback_names.user")
        usernames.add("#{fallback.downcase}_1")
        usernames.add("#{fallback.downcase}_123")

        username1 = finder.find_available_name("")
        119.times { finder.find_available_name("") }
        username2 = finder.find_available_name("")
        username3 = finder.find_available_name("")

        expect(username1).to eq("#{fallback}_2")
        expect(username2).to eq("#{fallback}_122")
        expect(username3).to eq("#{fallback}_124")
      end
    end
  end
end
