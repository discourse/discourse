# frozen_string_literal: true

RSpec.describe Migrations::Importer::GroupNameFinder do
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
    SiteSetting.here_mention = "here"
  end

  describe "#find_available_name" do
    context "with basic functionality" do
      it "returns the group name when available" do
        name = finder.find_available_name("developers")
        expect(name).to eq("developers")
      end

      it "sanitizes group names" do
        name = finder.find_available_name("Dev Team!")
        expect(name).to eq("Dev_Team")
      end

      it "uses fallback group name with suffix for blank input" do
        name = finder.find_available_name("")
        fallback = I18n.t("importer.fallback_names.group")
        expect(name).to eq("#{fallback}_1")
      end

      it "uses fallback when sanitization results in empty string" do
        name = finder.find_available_name("___")
        fallback = I18n.t("importer.fallback_names.group")
        expect(name).to eq("#{fallback}_1")
      end
    end

    context "when truncating names" do
      it "truncates long group names to max length" do
        long_name = "a" * 70
        name = finder.find_available_name(long_name)
        expect(name).to eq("a" * 60)
      end

      it "removes invalid trailing characters after truncation" do
        long_name = "a" * 58 + "_."
        name = finder.find_available_name(long_name)
        expect(name).to eq("a" * 58)
      end
    end

    context "when generating suffixes" do
      it "generates sequential suffixes for duplicates" do
        name1 = finder.find_available_name("team")
        name2 = finder.find_available_name("team")
        name3 = finder.find_available_name("team")
        11.times { finder.find_available_name("team") }
        name4 = finder.find_available_name("team")

        expect(name1).to eq("team")
        expect(name2).to eq("team_1")
        expect(name3).to eq("team_2")
        expect(name4).to eq("team_14")
      end

      it "handles case-insensitive duplicates" do
        name1 = finder.find_available_name("DevTeam")
        name2 = finder.find_available_name("devteam")
        name3 = finder.find_available_name("devTeam")

        expect(name1).to eq("DevTeam")
        expect(name2).to eq("devteam_1")
        expect(name3).to eq("devTeam_2")
      end

      it "truncates name to fit suffix when needed" do
        long_name = "a" * 50 + "1234567890"
        finder.find_available_name(long_name)
        name = finder.find_available_name(long_name)

        expected_truncated_name = "a" * 50 + "12345678"
        expect(name).to eq("#{expected_truncated_name}_1")
      end

      it "truncates further when suffix length increases" do
        long_name = "a" * 50 + "1234567890"

        9.times { finder.find_available_name(long_name) }

        name = finder.find_available_name(long_name)
        expect(name).to eq("#{long_name[0, 58]}_9")

        # Suffix increases to _10, requires more truncation
        name = finder.find_available_name(long_name)
        expect(name).to eq("#{long_name[0, 57]}_1")

        # Continue with 57-char base through _99
        97.times { finder.find_available_name(long_name) }
        name = finder.find_available_name(long_name)
        expect(name).to eq("#{long_name[0, 57]}_99")

        # Suffix increases to _100, requires more truncation
        name = finder.find_available_name(long_name)
        expect(name).to eq("#{long_name[0, 56]}_1")
      end
    end

    context "with reserved `here` mention" do
      it "avoids `here` mention" do
        name = finder.find_available_name("here")
        expect(name).to eq("here_1")
      end

      it "handles empty `here` mention" do
        SiteSetting.here_mention = ""
        finder = described_class.new(shared_data)
        name = finder.find_available_name("here")
        expect(name).to eq("here")
      end
    end

    context "with Unicode group names enabled" do
      before { SiteSetting.unicode_usernames = true }

      it "handles Unicode normalization in `here` mention" do
        actual = "Löwe" # NFD
        expected = "Löwe" # NFC

        SiteSetting.here_mention = expected
        finder = described_class.new(shared_data)

        name = finder.find_available_name(actual)
        expect(name).to eq("#{expected}_1")
      end

      it "removes invalid grapheme clusters during sanitization" do
        name = finder.find_available_name("team👨‍👩‍👧‍👦test")
        expect(name).to eq("team_test")
      end

      it "truncates at grapheme boundaries for multi-byte characters" do
        # 94 characters, 67 grapheme clusters
        long_name =
          "बग_उत्पादन_और_पेशेवर_कॉफी_उपभोग_सेवा_प्रभाग_के_विभाग_के_मुख्य_अभियंता_सर्वोच्च_कमांडर_महोदय_जी"

        # 60 characters, 43 grapheme clusters
        name = finder.find_available_name(long_name)
        expect(name).to eq("बग_उत्पादन_और_पेशेवर_कॉफी_उपभोग_सेवा_प्रभाग_के_विभाग_के_मुख्")

        # 60 characters, 42 original grapheme clusters plus suffix
        name = finder.find_available_name(long_name)
        expect(name).to eq("बग_उत्पादन_और_पेशेवर_कॉफी_उपभोग_सेवा_प्रभाग_के_विभाग_के_मु_1")
        8.times { finder.find_available_name(long_name) }

        # 58 characters, 41 original grapheme clusters plus suffix
        name = finder.find_available_name(long_name)
        expect(name).to eq("बग_उत्पादन_और_पेशेवर_कॉफी_उपभोग_सेवा_प्रभाग_के_विभाग_के_1")
      end
    end

    context "with username conflicts" do
      it "prevents conflicts between group names and usernames" do
        usernames.add("john")
        name = finder.find_available_name("john")
        expect(name).to eq("john_1")
      end

      it "treats conflicts with usernames as case-insensitive" do
        usernames.add("testuser")
        name = finder.find_available_name("TestUser")
        expect(name).to eq("TestUser_1")
      end
    end

    context "when persisting across instances" do
      it "shares used group names via shared_data" do
        finder1 = described_class.new(shared_data)
        finder1.find_available_name("team")

        finder2 = described_class.new(shared_data)
        name = finder2.find_available_name("team")
        expect(name).to eq("team_1")
      end
    end

    context "when extracting suffixes from existing names" do
      it "extracts max suffix from dense sequences" do
        group_names.add("team")
        2000.times { |i| group_names.add("team_#{i + 1}") }

        name = finder.find_available_name("team")
        expect(name).to eq("team_2001")
      end

      it "handles sparse sequences efficiently" do
        group_names.add("team")
        group_names.add("team_5")
        group_names.add("team_1000")

        name = finder.find_available_name("team")
        expect(name).to eq("team_6")
      end
    end

    context "when ensuring minimum length" do
      subject(:finder) { described_class.new(shared_data, min_length: 5) }

      it "pads suffix with leading zeros for short names" do
        name1 = finder.find_available_name("ab")
        name2 = finder.find_available_name("ab")
        name3 = finder.find_available_name("ab")

        expect(name1).to eq("ab_01")
        expect(name2).to eq("ab_02")
        expect(name3).to eq("ab_03")
      end

      it "stops padding when suffix grows naturally" do
        name = finder.find_available_name("a")
        expect(name).to eq("a_001")

        98.times { finder.find_available_name("a") }
        name = finder.find_available_name("a")
        expect(name).to eq("a_100")
      end
    end

    context "with fallback name conflicts" do
      it "finds next available fallback name when some are already used" do
        fallback = I18n.t("importer.fallback_names.group")
        group_names.add("#{fallback.downcase}_1")
        group_names.add("#{fallback.downcase}_123")

        name1 = finder.find_available_name("")
        119.times { finder.find_available_name("") }
        name2 = finder.find_available_name("")
        name3 = finder.find_available_name("")

        expect(name1).to eq("#{fallback}_2")
        expect(name2).to eq("#{fallback}_122")
        expect(name3).to eq("#{fallback}_124")
      end
    end
  end
end
