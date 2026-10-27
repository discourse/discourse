# frozen_string_literal: true

RSpec.describe AiDecisionModelSerializer do
  fab!(:admin)
  fab!(:user)
  fab!(:moderator)
  fab!(:decision_model) do
    Fabricate(:decision_model, custom_headers: [{ name: "X-Token", value: "sensitive-token" }])
  end

  before { enable_current_plugin }

  it "only includes custom headers with an administrator scope" do
    serialized = described_class.new(decision_model, scope: admin.guardian, root: false).as_json
    expect(serialized[:custom_headers]).to eq(decision_model.custom_headers)

    [nil, user.guardian, moderator.guardian].each do |scope|
      serialized = described_class.new(decision_model, scope:, root: false).as_json
      expect(serialized).not_to have_key(:custom_headers)
    end
  end
end
