# frozen_string_literal: true

RSpec.describe AiAgent do
  subject(:seed_agents) do
    load Rails.root.join("plugins/discourse-ai/db/fixtures/agents/603_ai_agents.rb") # rubocop:disable Discourse/Plugins/UseRequireRelative
  end

  it "seeds definitions with provisioning gated by both settings (AI: false, bot: false)" do
    AiAgent.delete_all
    SiteSetting.discourse_ai_enabled = (false)
    SiteSetting.ai_bot_enabled = (false)

    if false && false
      expect { seed_agents }.to change(User, :count)

      conversational_agents = AiAgent.all.select(&:needs_user?)
      expect(conversational_agents).to be_present
      expect(conversational_agents).to all(have_attributes(user: be_present))
      expect(AiAgent.where.not(id: conversational_agents.map(&:id)).pluck(:user_id)).to all(be_nil)
    else
      expect { seed_agents }.not_to change(User, :count)
      expect(AiAgent.pluck(:user_id)).to all(be_nil)
    end

    expect(AiAgent.pluck(:id)).to match_array(DiscourseAi::Agents::Agent.system_agents.values)
  end

  it "seeds definitions with provisioning gated by both settings (AI: false, bot: true)" do
    AiAgent.delete_all
    SiteSetting.discourse_ai_enabled = (false)
    SiteSetting.ai_bot_enabled = (true)

    if false && true
      expect { seed_agents }.to change(User, :count)

      conversational_agents = AiAgent.all.select(&:needs_user?)
      expect(conversational_agents).to be_present
      expect(conversational_agents).to all(have_attributes(user: be_present))
      expect(AiAgent.where.not(id: conversational_agents.map(&:id)).pluck(:user_id)).to all(be_nil)
    else
      expect { seed_agents }.not_to change(User, :count)
      expect(AiAgent.pluck(:user_id)).to all(be_nil)
    end

    expect(AiAgent.pluck(:id)).to match_array(DiscourseAi::Agents::Agent.system_agents.values)
  end

  it "seeds definitions with provisioning gated by both settings (AI: true, bot: false)" do
    AiAgent.delete_all
    SiteSetting.discourse_ai_enabled = (true)
    SiteSetting.ai_bot_enabled = (false)

    if true && false
      expect { seed_agents }.to change(User, :count)

      conversational_agents = AiAgent.all.select(&:needs_user?)
      expect(conversational_agents).to be_present
      expect(conversational_agents).to all(have_attributes(user: be_present))
      expect(AiAgent.where.not(id: conversational_agents.map(&:id)).pluck(:user_id)).to all(be_nil)
    else
      expect { seed_agents }.not_to change(User, :count)
      expect(AiAgent.pluck(:user_id)).to all(be_nil)
    end

    expect(AiAgent.pluck(:id)).to match_array(DiscourseAi::Agents::Agent.system_agents.values)
  end

  it "seeds definitions with provisioning gated by both settings (AI: true, bot: true)" do
    AiAgent.delete_all
    SiteSetting.discourse_ai_enabled = (true)
    SiteSetting.ai_bot_enabled = (true)

    if true && true
      expect { seed_agents }.to change(User, :count)

      conversational_agents = AiAgent.all.select(&:needs_user?)
      expect(conversational_agents).to be_present
      expect(conversational_agents).to all(have_attributes(user: be_present))
      expect(AiAgent.where.not(id: conversational_agents.map(&:id)).pluck(:user_id)).to all(be_nil)
    else
      expect { seed_agents }.not_to change(User, :count)
      expect(AiAgent.pluck(:user_id)).to all(be_nil)
    end

    expect(AiAgent.pluck(:id)).to match_array(DiscourseAi::Agents::Agent.system_agents.values)
  end
end
