# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::MentionClassifier do
  let(:mention_type) { Migrations::Database::IntermediateDB::Enums::MentionType }

  it "classifies a plain name as a user mention" do
    expect(described_class.new.call("gerhard")).to eq(mention_type::USER)
  end

  it "classifies @all as an all mention" do
    expect(described_class.new.call("all")).to eq(mention_type::ALL)
    expect(described_class.new.call("All")).to eq(mention_type::ALL)
  end

  describe "here mentions" do
    it "recognizes the default here_mention name" do
      expect(described_class.new.call("here")).to eq(mention_type::HERE)
    end

    it "honors a custom here_mention setting value" do
      classifier = described_class.new(here_mention: "staff")

      expect(classifier.call("staff")).to eq(mention_type::HERE)
      expect(classifier.call("here")).to eq(mention_type::USER)
    end

    it "disables here-detection when here_mention is blank" do
      expect(described_class.new(here_mention: nil).call("here")).to eq(mention_type::USER)
    end
  end

  describe "group mentions" do
    subject(:classifier) { described_class.new(group_names: %w[Admins Moderators]) }

    it "recognizes a source group name, case-insensitively" do
      expect(classifier.call("admins")).to eq(mention_type::GROUP)
      expect(classifier.call("Moderators")).to eq(mention_type::GROUP)
    end

    it "treats an unknown name as a user mention" do
      expect(classifier.call("gerhard")).to eq(mention_type::USER)
    end

    # Same name, two Unicode forms: the group is stored decomposed (NFD), the
    # mention typed composed (NFC). Plain downcase would treat them as different;
    # normalization makes them match.
    it "matches regardless of Unicode encoding" do
      name = "Café"
      classifier = described_class.new(group_names: [name.unicode_normalize(:nfd)])

      expect(classifier.call(name.unicode_normalize(:nfc))).to eq(mention_type::GROUP)
    end
  end
end
