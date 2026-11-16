# frozen_string_literal: true

RSpec.describe AiAgent do
  subject(:seed_agents) do
    load Rails.root.join("plugins/discourse-ai/db/fixtures/agents/603_ai_agents.rb") # rubocop:disable Discourse/Plugins/UseRequireRelative
  end

  shared_examples "seeding definitions without bot provisioning" do |ai_enabled:, bot_enabled:|
    it "seeds every system definition without creating users" do
      AiAgent.delete_all
      SiteSetting.discourse_ai_enabled = ai_enabled
      SiteSetting.ai_bot_enabled = bot_enabled

      expect { seed_agents }.not_to change(User, :count)
      expect(AiAgent.pluck(:user_id)).to all(be_nil)

      expect(AiAgent.pluck(:id)).to match_array(DiscourseAi::Agents::Agent.system_agents.values)
    end
  end

  context "with both AI and bot provisioning disabled" do
    include_examples "seeding definitions without bot provisioning",
                     ai_enabled: false,
                     bot_enabled: false
  end

  context "with AI disabled and bot provisioning enabled" do
    include_examples "seeding definitions without bot provisioning",
                     ai_enabled: false,
                     bot_enabled: true
  end

  context "with AI enabled and bot provisioning disabled" do
    include_examples "seeding definitions without bot provisioning",
                     ai_enabled: true,
                     bot_enabled: false
  end

  context "with both AI and bot provisioning enabled" do
    it "seeds definitions and provisions conversational agent users" do
      AiAgent.delete_all
      SiteSetting.discourse_ai_enabled = true
      SiteSetting.ai_bot_enabled = true

      expect { seed_agents }.to change(User, :count)

      conversational_agents = AiAgent.all.select(&:needs_user?)
      expect(conversational_agents).to be_present
      expect(conversational_agents).to all(have_attributes(user: be_present))
      expect(AiAgent.where.not(id: conversational_agents.map(&:id)).pluck(:user_id)).to all(be_nil)

      expect(AiAgent.pluck(:id)).to match_array(DiscourseAi::Agents::Agent.system_agents.values)
    end
  end
end
