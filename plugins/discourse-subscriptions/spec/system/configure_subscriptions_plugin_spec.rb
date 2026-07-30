# frozen_string_literal: true

describe "Configure subscriptions plugin", allow_network: ["js.stripe.com"] do
  fab!(:admin)

  let(:config_page) { PageObjects::Pages::AdminSubscriptionsConfig.new }

  before do
    SiteSetting.discourse_subscriptions_enabled = true
    sign_in(admin)
  end

  it "takes the admin to the products tab, alongside the other tabs, once Stripe keys are set" do
    SiteSetting.discourse_subscriptions_secret_key = "sk_test_51xuu"
    SiteSetting.discourse_subscriptions_public_key = "pk_test_51xuu"
    ::Stripe::Product.stubs(:list).returns({ data: [] })

    config_page.visit

    expect(page).to have_current_path("/admin/plugins/discourse-subscriptions/products")
    expect(config_page).to have_tabs("Settings", "Products", "Coupons", "Subscriptions")
  end

  it "takes the admin to the settings tab when Stripe has not been set up yet" do
    config_page.visit

    expect(page).to have_current_path("/admin/plugins/discourse-subscriptions/settings")
    expect(config_page).to have_tabs("Settings", "Products", "Coupons", "Subscriptions")
  end

  it "tells the admin why the products tab is empty rather than sending them back to settings" do
    config_page.visit
    config_page.click_tab("Products")

    expect(page).to have_current_path("/admin/plugins/discourse-subscriptions/products")
    expect(config_page).to have_stripe_unconfigured_notice
  end
end
