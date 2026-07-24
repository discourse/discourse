# frozen_string_literal: true

describe DiscourseAi::Agents::LocaleDetector do
  describe "#system_prompt" do
    let(:prompt) { described_class.new.system_prompt }

    context "when content_localization_supported_locales is blank" do
      before { SiteSetting.content_localization_supported_locales = "" }

      it "leaves the static block intact with no extra entries" do
        expect(prompt).to include(
          "- Korean: ko\n\nIf the language is not in this list, use the appropriate IETF language tag code.",
        )
      end
    end

    context "with obscure codes" do
      before { SiteSetting.content_localization_supported_locales = "nb_NO|zh_TW" }

      it "appends every recognisable code in hyphenated form" do
        expect(prompt).to include(
          "- Korean: ko\n- Norwegian Bokmål: nb-NO\n- Chinese: zh-TW\n\nIf the language is not in this list, use the appropriate IETF language tag code.",
        )
        expect(prompt).to include("- Norwegian Bokmål: nb-NO")
        expect(prompt).to include("- Chinese: zh-TW")
      end
    end

    context "when supported locales overlap with the static list" do
      before { SiteSetting.content_localization_supported_locales = "ja" }

      it "does not duplicate codes already listed" do
        expect(prompt.scan(/^\s*- Japanese: ja\s*$/).size).to eq(1)
      end
    end
  end
end
