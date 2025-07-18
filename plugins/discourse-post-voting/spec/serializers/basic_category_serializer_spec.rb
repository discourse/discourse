# frozen_string_literal: true

require "rails_helper"

describe BasicCategorySerializer do
  fab!(:category)

  let(:serialized) do
    serializer = BasicCategorySerializer.new(category, root: false)
    serializer.as_json
  end

  before do
    category.custom_fields[PostVoting::CREATE_AS_POST_VOTING_DEFAULT] = true
    category.save_custom_fields(true)
  end

  context "with qa enabled" do
    before { SiteSetting.post_voting_enabled = true }

    it "should return post_voting category attributes" do
      expect(serialized[:create_as_post_voting_default]).to eq(true)
    end
  end

  context "with qa disabled" do
    before { SiteSetting.post_voting_enabled = false }

    it "should not return qa category attributes" do
      expect(serialized.key?(:create_as_post_voting_default)).to eq(false)
    end
  end
end
