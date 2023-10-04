# frozen_string_literal: true

require "rails_helper"

describe Chat::NullMessage do
  subject(:null_message) { described_class.new }

  describe "#user" do
    it "returns nil" do
      expect(null_message.user).to be_nil
    end
  end

  describe "#excerpt" do
    it "returns nil" do
      expect(null_message.excerpt(max_length: 1)).to be_nil
    end
  end

  describe "#id" do
    it "returns nil" do
      expect(null_message.id).to be_nil
    end
  end

  describe "#create_at" do
    it "returns a Time object" do
      expect(null_message.created_at).to be_a(Time)
    end
  end
end
