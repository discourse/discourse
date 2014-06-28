require 'spec_helper'
require_dependency 'user'

describe UserSerializer do

  context "with a user" do
    let(:user) { Fabricate.build(:user, user_profile: Fabricate.build(:user_profile) ) }
    let(:serializer) { UserSerializer.new(user, scope: Guardian.new, root: false) }
    let(:json) { serializer.as_json }

    it "produces json" do
      json.should be_present
    end

    context "with `enable_names` true" do
      before do
        SiteSetting.stubs(:enable_names?).returns(true)
      end

      it "has a name" do
        json[:name].should be_present
      end
    end

    context "with `enable_names` false" do
      before do
        SiteSetting.stubs(:enable_names?).returns(false)
      end

      it "has a name" do
        json[:name].should be_blank
      end
    end

    context "with filled out profile background" do
      before do
        user.user_profile.profile_background = 'http://background.com'
      end

      it "has a profile background" do
        expect(json[:profile_background]).to eq 'http://background.com'
      end
    end

    context "with filled out website" do
      before do
        user.user_profile.website = 'http://example.com'
      end

      it "has a website" do
        expect(json[:website]).to eq 'http://example.com'
      end
    end

    context "with filled out bio" do
      before do
        user.user_profile.bio_raw = 'my raw bio'
        user.user_profile.bio_cooked = 'my cooked bio'
      end

      it "has a bio" do
        expect(json[:bio_raw]).to eq 'my raw bio'
      end

      it "has a cooked bio" do
        expect(json[:bio_cooked]).to eq 'my cooked bio'
      end
    end
  end
end
