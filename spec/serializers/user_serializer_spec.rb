require 'spec_helper'
require_dependency 'user'

describe UserSerializer do

  context "with a user" do
    let(:user) { Fabricate.build(:user) }
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


  end

end
