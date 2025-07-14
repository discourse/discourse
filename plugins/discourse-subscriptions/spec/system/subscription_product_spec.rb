# frozen_string_literal: true

describe "Subscription products", type: :system do
  fab!(:admin)
  fab!(:product) { Fabricate(:product, external_id: "prod_OiK") }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:product_subscriptions_page) { PageObjects::Pages::AdminSubscriptionProduct.new }

  before do
    SiteSetting.discourse_subscriptions_enabled = true

    SiteSetting.discourse_subscriptions_secret_key = "sk_test_51xuu"
    SiteSetting.discourse_subscriptions_public_key = "pk_test_51xuu"

    # # this needs to be stubbed or it will try to make a request to stripe
    one_product = {
      id: "prod_OiK",
      active: true,
      name: "Tomtom",
      metadata: {
        description: "Photos of tomtom",
        repurchaseable: true,
      },
    }
    ::Stripe::Product.stubs(:list).returns({ data: [one_product] })
    ::Stripe::Product.stubs(:delete).returns({ id: "prod_OiK" })
    ::Stripe::Product.stubs(:retrieve).returns(one_product)
    ::Stripe::Price.stubs(:list).returns({ data: [] })
  end

  it "shows the login screen" do
    visit("/s")

    find("button.login-required.subscriptions").click

    expect(page).to have_css("#login-form")
  end

  it "shows products on the products and allows deletion" do
    sign_in(admin)

    product_subscriptions_page.visit_products.has_product?("Tomtom")

    product_subscriptions_page.click_trash_nth_row(1)
    dialog.click_yes

    product_subscriptions_page.has_number_of_products?(0)
  end
end
