# frozen_string_literal: true

describe CategorySerializer do
  fab!(:category)

  it "does not return enable_topic_voting voting disabled" do
    SiteSetting.topic_voting_enabled = false

    json = CategorySerializer.new(category, root: false).as_json

    expect(json[:custom_fields]).to eq({})
  end

  it "returns enable_topic_voting when voting enabled" do
    SiteSetting.topic_voting_enabled = true

    json = CategorySerializer.new(category, root: false).as_json

    expect(json[:custom_fields]).to eq({ "enable_topic_voting" => false })
  end
end
