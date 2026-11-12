# frozen_string_literal: true

RSpec.describe "Anonymous" do
  fab!(:topic)

  before { chat_system_bootstrap }

  context "when anonymous" do
    it "doesn’t cause issues" do
      visit("/")

      expect(page).to have_content(topic.title)
    end
  end
end
