# frozen_string_literal: true

RSpec.describe "AI Usage Admin Page", type: :system do
  fab!(:admin)

  before do
    enable_current_plugin
    sign_in(admin)
  end

  context "when using custom date range functionality" do
    it "allows selecting custom date range without JavaScript errors" do
      visit "/admin/plugins/discourse-ai/ai-usage"
      expect(page).to have_css(".ai-usage")

      # Click custom date button to show date picker
      find(".ai-usage__period-buttons .btn-default:last-child").click
      expect(page).to have_css(".ai-usage__custom-date-pickers")

      # Set dates
      date_inputs = all(".ai-usage__custom-date-pickers input[type='date']")
      date_inputs[0].set("2025-07-01")
      date_inputs[1].set("2025-07-31")

      # Verify dates are set correctly (preview functionality)
      expect(date_inputs[0].value).to eq("2025-07-01")
      expect(date_inputs[1].value).to eq("2025-07-31")

      # Click refresh - this used to cause visual glitches and date reversion
      find(".ai-usage__custom-date-pickers .btn", text: I18n.t("js.refresh")).click

      # Wait for any potential async operations
      sleep(1)

      expect(page).to have_css(".ai-usage__summary")
    end
  end
end
