# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  include_context "with raw extractor"

  let(:mention_names) { Migrations::CompactStringSet.new(%w[κοσμος κοσμοσ]) }
  let(:raw_hashtag_name_list) { %w[κοσμος κοσμοσ] }

  it "records each sigma username in its original spelling" do
    output = extract("@κοσμος @κοσμοσ @ΚΟΣΜΟΣ")

    expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[κοσμος κοσμοσ ΚΟΣΜΟΣ])
    expect(output).to eq(buffer.mentions.map { |row| row[:placeholder] }.join(" "))
    expect(extractor.engine_refusals).to be_empty
  end

  it "preserves shielded sigma spellings while extracting live mentions" do
    output = extract("`@κοσμος` @κοσμοσ @κοσμος")

    expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[κοσμοσ κοσμος])
    expect(output).to eq("`@κοσμος` #{buffer.mentions.map { |row| row[:placeholder] }.join(" ")}")
    expect(extractor.engine_refusals).to be_empty
  end

  it "records each hashtag with its original sigma identity" do
    output = extract("#κοσμος #κοσμοσ #ΚΟΣΜΟΣ")

    expect(buffer.hashtags.map { |row| row[:name] }).to eq(%w[κοσμος κοσμοσ ΚΟΣΜΟΣ])
    expect(output).to eq(buffer.hashtags.map { |row| row[:placeholder] }.join(" "))
    expect(extractor.engine_refusals).to be_empty
  end

  context "when only the ordinary sigma identity exists" do
    let(:mention_names) { Migrations::CompactStringSet.new(%w[κοσμοσ]) }
    let(:raw_hashtag_name_list) { %w[κοσμοσ] }

    it "leaves unknown sigma spellings literal in a body with known constructs" do
      output = extract("@κοσμος @κοσμοσ #κοσμος #ΚΟΣΜΟΣ")

      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[κοσμοσ])
      expect(buffer.hashtags.map { |row| row[:name] }).to eq(%w[ΚΟΣΜΟΣ])
      expect(output).to eq(
        "@κοσμος #{buffer.mentions.first[:placeholder]} #κοσμος #{buffer.hashtags.first[:placeholder]}",
      )
      expect(extractor.engine_refusals).to be_empty
    end
  end
end
