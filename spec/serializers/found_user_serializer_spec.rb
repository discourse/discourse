# frozen_string_literal: true

RSpec.describe FoundUserSerializer do
  fab!(:user) { Fabricate(:user) }
  let(:serializer) { described_class.new(user, root: false) }

  describe "#id" do
    it "returns user id" do
      json = serializer.as_json
      expect(json.keys).to include :id
      expect(json[:id]).to eq(user.id)
    end
  end

  describe "#name" do
    it "returns name if enabled in site settings" do
      SiteSetting.enable_names = true
      json = serializer.as_json
      expect(json.keys).to include :name
      expect(json[:name]).to eq(user.name)
    end

    it "doesn't return name if disabled in site settings" do
      SiteSetting.enable_names = false
      json = serializer.as_json
      expect(json.keys).not_to include :name
    end
  end
end
