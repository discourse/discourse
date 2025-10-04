# frozen_string_literal: true

require "rails_helper"

RSpec.describe YjsTextOperations do
  describe ".create_initial_state" do
    it "creates initial Yjs state with content" do
      content = "Hello, world!"
      state = YjsTextOperations.create_initial_state(content)

      expect(state).to be_a(String)
      parsed = JSON.parse(state)
      expect(parsed["content"]).to eq(content)
      expect(parsed["timestamp"]).to be_present
      expect(parsed["version"]).to eq(1)
    end

    it "creates initial Yjs state with empty content" do
      state = YjsTextOperations.create_initial_state("")

      expect(state).to be_a(String)
      parsed = JSON.parse(state)
      expect(parsed["content"]).to eq("")
    end
  end

  describe ".apply_update" do
    it "applies Yjs update to document state" do
      initial_state = YjsTextOperations.create_initial_state("Hello")
      update = YjsTextOperations.create_initial_state("Hello World")

      result = YjsTextOperations.apply_update(initial_state, update)

      expect(result).to be_a(String)
    end
  end

  describe ".get_text_content" do
    it "extracts text content from Yjs state" do
      content = "Test content"
      state = YjsTextOperations.create_initial_state(content)

      result = YjsTextOperations.get_text_content(state)

      expect(result).to eq(content)
    end
  end

  describe ".merge_updates" do
    it "merges multiple Yjs updates" do
      update1 = YjsTextOperations.create_initial_state("Hello")
      update2 = YjsTextOperations.create_initial_state("World")

      merged = YjsTextOperations.merge_updates([update1, update2])

      expect(merged).to eq(update2) # Should return the last update
    end
  end
end
