# frozen_string_literal: true

RSpec.describe UserOption do
  describe "#chat_separate_sidebar_mode" do
    it "is present" do
      expect(described_class.new.chat_separate_sidebar_mode).to eq("default")
    end
  end
  describe "#show_thread_title_prompts" do
    it "is present" do
      expect(described_class.new.show_thread_title_prompts).to eq(true)
    end
  end
  describe "#chat_announce_new_messages" do
    it "defaults to true" do
      expect(described_class.new.chat_announce_new_messages).to eq(true)
    end
  end
  describe "#chat_new_message_sound" do
    it "defaults to false" do
      expect(described_class.new.chat_new_message_sound).to eq(false)
    end
  end
  describe "#chat_quick_reaction_type" do
    it "is present with frequent as default" do
      expect(described_class.new.chat_quick_reaction_type).to eq("frequent")
    end
  end
end
