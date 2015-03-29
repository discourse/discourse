require 'spec_helper'

describe SiteText do

  it { is_expected.to validate_presence_of :value }


  describe "#text_for" do

    it "returns an empty string for a missing text_type" do
      expect(SiteText.text_for('something_random')).to eq("")
    end

    it "returns the default value for a text` type with a default" do
      expect(SiteText.text_for("usage_tips")).to be_present
    end

    it "correctly expires and bypasses cache" do
      SiteSetting.enable_sso = false
      text = SiteText.create!(text_type: "got.sso", value: "got sso: %{enable_sso}")
      expect(SiteText.text_for("got.sso")).to eq("got sso: false")
      SiteText.text_for("got.sso").frozen? == true

      SiteSetting.enable_sso = true
      wait_for do
        SiteText.text_for("got.sso") == "got sso: true"
      end

      text.value = "I gots sso: %{enable_sso}"
      text.save!

      wait_for do
        SiteText.text_for("got.sso") == "I gots sso: true"
      end

      expect(SiteText.text_for("got.sso", enable_sso: "frog")).to eq("I gots sso: frog")
    end

    context "without replacements" do
      let!(:site_text) { Fabricate(:site_text_basic) }

      it "returns the simple string" do
        expect(SiteText.text_for('breaking.bad')).to eq("best show ever")
      end

    end

    context "with replacements" do
      let!(:site_text) { Fabricate(:site_text) }
      let(:replacements) { {flower: 'roses', food: 'grapes'} }

      it "returns the correct string with replacements" do
        expect(SiteText.text_for('great.poem', replacements)).to eq("roses are red. grapes are blue.")
      end

      it "doesn't mind extra keys in the replacements" do
        expect(SiteText.text_for('great.poem', replacements.merge(extra: 'key'))).to eq("roses are red. grapes are blue.")
      end

      it "ignores missing keys" do
        expect(SiteText.text_for('great.poem', flower: 'roses')).to eq("roses are red. %{food} are blue.")
      end
    end


    context "replacing site_settings" do
      let!(:site_text) { Fabricate(:site_text_site_setting) }

      it "replaces site_settings by default" do
        SiteSetting.title = "Evil Trout"
        expect(SiteText.text_for('site.replacement')).to eq("Evil Trout is evil.")
      end

      it "allows us to override the default site settings" do
        SiteSetting.title = "Evil Trout"
        expect(SiteText.text_for('site.replacement', title: 'Good Tuna')).to eq("Good Tuna is evil.")
      end

    end

  end

end
