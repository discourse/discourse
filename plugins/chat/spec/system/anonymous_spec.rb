# frozen_string_literal: true

RSpec.describe "Anonymous", type: :system, js: true do
  fab!(:topic) { Fabricate(:topic) }

  before { chat_system_bootstrap }

  context "when anonymous" do
    it "doesn’t cause issues" do
      visit("/")

      expect(page).to have_content(topic.title)
    end
  end
end
