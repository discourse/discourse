require 'rails_helper'
require_dependency 'user'

describe BasicUserSerializer do

  context "name" do
    let(:user) { Fabricate.build(:user) }
    let(:serializer) { BasicUserSerializer.new(user, scope: Guardian.new(user), root: false) }
    let(:json) { serializer.as_json }

    it "returns the username" do
      expect(json[:username]).to be_present
    end

    it "returns the name it when `enable_names` is true" do
      SiteSetting.enable_names = true
      expect(json[:name]).to be_present
    end

    it "doesn't return the name it when `enable_names` is false" do
      SiteSetting.enable_names = false
      expect(json[:name]).to be_blank
    end

  end

end
