# frozen_string_literal: true

RSpec.describe AiPersona, type: :multisite do
  before { enable_current_plugin }

  it "is able to amend settings on system personas on multisite" do
    persona = AiPersona.find_by(name: "Designer")
    expect(persona.allow_personal_messages).to eq(true)
    persona.update!(allow_personal_messages: false)

    instance = persona.class_instance
    expect(instance.allow_personal_messages).to eq(false)

    test_multisite_connection("second") do
      persona = AiPersona.find_by(name: "Designer")
      expect(persona.allow_personal_messages).to eq(true)
      instance = persona.class_instance
      expect(instance.name).to eq("Designer")
      expect(instance.allow_personal_messages).to eq(true)
    end

    persona = AiPersona.find_by(name: "Designer")
    instance = persona.class_instance
    expect(instance.allow_personal_messages).to eq(false)
  end
end
