# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::MentionResolver do
  MentionType = Migrations::Database::IntermediateDB::Enums::MentionType

  it "classifies a plain name as a user mention" do
    expect(described_class.new.call("gerhard")).to eq(MentionType::USER)
  end

  it "classifies @all as an all mention" do
    expect(described_class.new.call("all")).to eq(MentionType::ALL)
    expect(described_class.new.call("All")).to eq(MentionType::ALL)
  end

  describe "here mentions" do
    it "recognizes the default here_mention name" do
      expect(described_class.new.call("here")).to eq(MentionType::HERE)
    end

    it "honors a custom here_mention setting value" do
      resolver = described_class.new(here_mention: "staff")

      expect(resolver.call("staff")).to eq(MentionType::HERE)
      expect(resolver.call("here")).to eq(MentionType::USER)
    end
  end

  describe "group mentions" do
    subject(:resolver) { described_class.new(group_names: %w[Admins Moderators]) }

    it "recognizes a source group name, case-insensitively" do
      expect(resolver.call("admins")).to eq(MentionType::GROUP)
      expect(resolver.call("Moderators")).to eq(MentionType::GROUP)
    end

    it "treats an unknown name as a user mention" do
      expect(resolver.call("gerhard")).to eq(MentionType::USER)
    end

    # Same name, two Unicode forms: the group is stored decomposed (NFD), the
    # mention typed composed (NFC). Plain downcase would treat them as different;
    # normalization makes them match.
    it "matches regardless of Unicode encoding" do
      name = "Café"
      resolver = described_class.new(group_names: [name.unicode_normalize(:nfd)])

      expect(resolver.call(name.unicode_normalize(:nfc))).to eq(MentionType::GROUP)
    end
  end
end
