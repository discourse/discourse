# frozen_string_literal: true

RSpec.describe AiAgent, type: :multisite do
  before { enable_current_plugin }

  it "provisions users using the current site's settings and connection" do
    SiteSetting.ai_bot_enabled = true
    default_agent = Fabricate(:ai_agent)

    test_multisite_connection("second") do
      SiteSetting.discourse_ai_enabled = true
      SiteSetting.ai_bot_enabled = false
      second_agent = Fabricate(:ai_agent)

      expect { AiAgent.ensure_users! }.not_to change(User, :count)
      expect(second_agent.reload.user_id).to be_nil

      SiteSetting.ai_bot_enabled = true

      expect(second_agent.reload.user).to be_present
    end

    expect(default_agent.reload.user_id).to be_nil
    AiAgent.ensure_users!
    expect(default_agent.reload.user).to be_present
  end

  it "is able to amend settings on system agents on multisite" do
    agent = AiAgent.find_by(name: "Designer")
    expect(agent.allow_personal_messages).to eq(true)
    agent.update!(allow_personal_messages: false)

    instance = agent.class_instance
    expect(instance.allow_personal_messages).to eq(false)

    test_multisite_connection("second") do
      agent = AiAgent.find_by(name: "Designer")
      expect(agent.allow_personal_messages).to eq(true)
      instance = agent.class_instance
      expect(instance.name).to eq("Designer")
      expect(instance.allow_personal_messages).to eq(true)
    end

    agent = AiAgent.find_by(name: "Designer")
    instance = agent.class_instance
    expect(instance.allow_personal_messages).to eq(false)
  end
end
