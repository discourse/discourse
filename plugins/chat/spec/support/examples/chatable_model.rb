# frozen_string_literal: true

RSpec.shared_examples "a chatable model" do
  describe "#chat_channel" do
    subject(:chat_channel) { chatable.chat_channel }

    it "returns a new chat channel model" do
      expect(chat_channel).to have_attributes persisted?: false,
                      class: channel_class,
                      chatable: chatable
    end
  end

  describe "#create_chat_channel!" do
    subject(:create_chat_channel) { chatable.create_chat_channel!(name: name) }

    let(:name) { "a custom name" }

    it "creates a proper chat channel" do
      expect { create_chat_channel }.to change { channel_class.count }.by(1)
      expect(channel_class.last).to have_attributes chatable: chatable, name: name
    end
  end
end
