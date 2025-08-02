# frozen_string_literal: true

RSpec.describe "Campaign Banner", type: :system do
  fab!(:user)
  fab!(:contributor) { Fabricate(:user, username: "contributor1") }

  before do
    ::Stripe::Product.stubs(:list).returns({ data: [] })
    ::Stripe::Price.stubs(:list).returns({ data: [] })

    SiteSetting.discourse_subscriptions_campaign_enabled = true
    SiteSetting.discourse_subscriptions_campaign_show_contributors = true
    SiteSetting.discourse_subscriptions_campaign_banner_location = "Top"
    SiteSetting.discourse_subscriptions_campaign_goal = 100
    SiteSetting.discourse_subscriptions_campaign_amount_raised = 50
    SiteSetting.discourse_subscriptions_campaign_type = "Amount"
    SiteSetting.discourse_subscriptions_currency = "USD"
    SiteSetting.discourse_subscriptions_campaign_product = "prod_campaign"
    SiteSetting.discourse_subscriptions_secret_key = "sk_test_51xuu"
    SiteSetting.discourse_subscriptions_public_key = "pk_test_51xuu"
    SiteSetting.global_notice = nil
  end

  context "when plugin is disabled" do
    before { SiteSetting.discourse_subscriptions_enabled = false }

    it "does not render the campaign banner" do
      sign_in(user)
      visit("/")

      expect(page).not_to have_selector(".campaign-banner")
    end
  end

  context "when all conditions are met" do
    before { SiteSetting.discourse_subscriptions_enabled = true }

    it "renders the campaign banner and shows contributors" do
      sign_in(user)
      visit("/")

      expect(page).to have_selector(".above-main-container-outlet.subscriptions-campaign")

      expect(page).to have_selector(".campaign-banner")
      expect(page).to have_selector(".campaign-banner-info-header")
      expect(page).to have_selector(".campaign-banner-progress")
      expect(page).to have_selector(".campaign-banner-info-button")
    end
  end
end
