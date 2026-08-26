# frozen_string_literal: true

RSpec.describe Migrations::Converters::MarkdownEngine::EmojiData do
  describe ".unicode_replacements" do
    subject(:replacements) { described_class.unicode_replacements }

    it "maps unicode emoji to their names" do
      expect(replacements["😀"]).to eq("grinning_face")
    end

    it "includes skin-toned variants for tonable emoji" do
      expect(replacements.values).to include(a_string_matching(/:t2\z/))
    end

    it "keeps the symbol-like characters unmapped" do
      expect(replacements.values).not_to include("registered", "copyright", "trade_mark")
    end

    it "applies the extra text-symbol replacements" do
      expect(replacements["\u{2665}"]).to eq("heart")
    end
  end

  describe ".set_unicode_source" do
    it "produces a __setUnicode call" do
      expect(described_class.set_unicode_source).to start_with("__setUnicode({")
      expect(described_class.set_unicode_source).to end_with("});")
    end
  end
end
