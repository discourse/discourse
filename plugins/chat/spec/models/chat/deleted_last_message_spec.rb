# frozen_string_literal: true

require "rails_helper"

describe Chat::DeletedLastMessage do
  subject(:last_message) { described_class.new }

  describe "#user" do
    it "returns nil" do
      expect(last_message.user).to be_nil
    end
  end

  describe "#excerpt" do
    it "returns nil" do
      expect(last_message.excerpt(max_length: 1)).to be_nil
    end
  end

  describe "#id" do
    it "returns nil" do
      expect(last_message.id).to be_nil
    end
  end

  describe "#create_at" do
    it "returns a Time object" do
      expect(last_message.created_at).to be_a(Time)
    end
  end
end
