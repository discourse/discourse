# frozen_string_literal: true

RSpec.describe "Chat search", type: :system do
  fab!(:current_user, :user)
  fab!(:channel_1, :chat_channel)
  fab!(:message_1) do
    Fabricate(:chat_message, use_service: true, chat_channel: channel_1, message: "Hello world!")
  end
  fab!(:message_2) do
    Fabricate(
      :chat_message,
      use_service: true,
      chat_channel: channel_1,
      message: "This is a test message",
    )
  end
  fab!(:message_3) do
    Fabricate(
      :chat_message,
      use_service: true,
      chat_channel: channel_1,
      message: "Another message with different content",
    )
  end

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when searching for messages" do
    it "shows search results and allows navigation" do
      visit("/")

      # Open the filter/search
      # Note: This assumes there's a way to trigger the filter - you may need to add a button or keyboard shortcut
      # For now, we'll assume the filter is already open or can be triggered

      # expect(channel_page.filter).to be_visible

      # Search for "test"
      # channel_page.filter.fill_in("test")

      pause_test

      # Wait for results
      expect(channel_page.filter).to have_results
      expect(channel_page.filter.results_count).to eq(1)
      expect(channel_page.filter.current_result_position).to eq(1)

      # Navigate to next result (should wrap around)
      channel_page.filter.navigate_to_next_result
      expect(channel_page.filter.current_result_position).to eq(1)

      # Navigate to previous result
      channel_page.filter.navigate_to_previous_result
      expect(channel_page.filter.current_result_position).to eq(1)

      # Clear search
      channel_page.filter.clear
      expect(channel_page.filter).to have_no_results

      # Close filter
      channel_page.filter.close
      expect(channel_page.filter).to be_not_visible
    end

    it "shows no results message when no matches found" do
      chat_page.visit_channel(channel_1)

      expect(channel_page.filter).to be_visible

      # Search for something that doesn't exist
      channel_page.filter.fill_in("nonexistent")

      # Should show no results
      expect(channel_page.filter).to have_no_results
    end

    it "allows searching for multiple results" do
      chat_page.visit_channel(channel_1)

      expect(channel_page.filter).to be_visible

      # Search for "message" which should match multiple results
      channel_page.filter.fill_in("message")

      expect(channel_page.filter).to have_results
      expect(channel_page.filter.results_count).to eq(2)
      expect(channel_page.filter.current_result_position).to eq(1)

      # Navigate through results
      channel_page.filter.navigate_to_next_result
      expect(channel_page.filter.current_result_position).to eq(2)

      channel_page.filter.navigate_to_next_result
      expect(channel_page.filter.current_result_position).to eq(1) # Should wrap around
    end

    it "maintains search state when navigating between results" do
      chat_page.visit_channel(channel_1)

      expect(channel_page.filter).to be_visible

      channel_page.filter.fill_in("message")

      expect(channel_page.filter).to have_results
      expect(channel_page.filter.has_query?("message")).to be true

      # Navigate through results
      channel_page.filter.navigate_to_next_result
      expect(channel_page.filter.has_query?("message")).to be true

      # Clear and verify
      channel_page.filter.clear
      expect(channel_page.filter.has_query?("")).to be true
    end
  end

  context "when filter is not visible" do
    it "does not show search functionality" do
      chat_page.visit_channel(channel_1)

      # Assuming filter starts as not visible
      expect(channel_page.filter).to be_not_visible
    end
  end
end
