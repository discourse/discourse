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

    context "with filled out card background" do
      before do
        user.user_profile.card_background = 'http://card.com'
      end

      it "has a profile background" do
        expect(json[:card_background]).to eq 'http://card.com'
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

  context "with custom_fields" do
    let(:user) { Fabricate(:user) }
    let(:json) { UserSerializer.new(user, scope: Guardian.new, root: false).as_json }

    before do
      user.custom_fields['secret_field'] = 'Only for me to know'
      user.custom_fields['public_field'] = 'Everyone look here'
      user.save
    end

    it "doesn't serialize the fields by default" do
      json[:custom_fields]
      json[:custom_fields].should be_empty
    end

    it "serializes the fields listed in public_user_custom_fields site setting" do
      SiteSetting.stubs(:public_user_custom_fields).returns('public_field')
      json[:custom_fields]['public_field'].should == user.custom_fields['public_field']
      json[:custom_fields]['secret_field'].should == nil
    end
  end
end
