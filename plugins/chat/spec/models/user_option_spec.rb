# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserOption do
  describe "#chat_separate_sidebar_mode" do
    it "is present" do
      expect(described_class.new.chat_separate_sidebar_mode).to eq("default")
    end
  end
end
