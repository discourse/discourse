# frozen_string_literal: true

RSpec.describe AiAgent, type: :multisite do
  before { enable_current_plugin }

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
