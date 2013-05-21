require 'spec_helper'

describe SiteContent do

  it { should validate_presence_of :content }


  describe "#content_for" do

    it "returns an empty string for a missing content_type" do
      SiteContent.content_for('breaking.bad').should == ""
    end

    it "returns the default value for a content type with a default" do
      SiteContent.content_for("usage_tips").should be_present
    end

    context "without replacements" do
      let!(:site_content) { Fabricate(:site_content_basic) }

      it "returns the simple string" do
        SiteContent.content_for('breaking.bad').should == "best show ever"
      end

    end

    context "with replacements" do
      let!(:site_content) { Fabricate(:site_content) }
      let(:replacements) { {flower: 'roses', food: 'grapes'} }

      it "returns the correct string with replacements" do
        SiteContent.content_for('great.poem', replacements).should == "roses are red. grapes are blue."
      end

      it "doesn't mind extra keys in the replacements" do
        SiteContent.content_for('great.poem', replacements.merge(extra: 'key')).should == "roses are red. grapes are blue."
      end

      it "ignores missing keys" do
        SiteContent.content_for('great.poem', flower: 'roses').should == "roses are red. %{food} are blue."
      end
    end


    context "replacing site_settings" do
      let!(:site_content) { Fabricate(:site_content_site_setting) }

      it "replaces site_settings by default" do
        SiteSetting.stubs(:title).returns("Evil Trout")
        SiteContent.content_for('site.replacement').should == "Evil Trout is evil."
      end

      it "allows us to override the default site settings" do
        SiteSetting.stubs(:title).returns("Evil Trout")
        SiteContent.content_for('site.replacement', title: 'Good Tuna').should == "Good Tuna is evil."
      end

    end

  end

end
