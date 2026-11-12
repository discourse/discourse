# frozen_string_literal: true

RSpec.describe ComposerController do
  fab!(:admin)
  fab!(:ai_agent)
  fab!(:private_category) { Fabricate(:private_category, group: Group[:staff]) }
  fab!(:restricted_topic) { Fabricate(:topic, category: private_category) }

  before do
    enable_current_plugin
    sign_in(admin)
  end

  describe "#mentions" do
    it "suppresses the reachability warning when mentioning an AI bot user" do
      agent_user = ai_agent.create_user!

      get "/composer/mentions.json",
          params: {
            names: [agent_user.username.upcase],
            topic_id: restricted_topic.id,
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["users"]).to contain_exactly(agent_user.username_lower)
      expect(response.parsed_body["user_reasons"]).to eq({})
    end
  end
end
