require 'spec_helper'

describe SiteContent do

  it { should validate_presence_of :content }


  describe "#content_for" do

    it "returns an empty string for a missing content_type" do
      SiteContent.content_for('breaking.bad').should == ""
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

      it "raises an error with missing keys" do
        -> { SiteContent.content_for('great.poem', flower: 'roses') }.should raise_error
      end
    end

  end

end
