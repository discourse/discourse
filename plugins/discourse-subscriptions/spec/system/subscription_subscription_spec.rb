# frozen_string_literal: true

describe "Subscription products", type: :system do
  fab!(:admin)
  fab!(:user)
  fab!(:product) { Fabricate(:product, external_id: "prod_OiK") }
  fab!(:customer) do
    Fabricate(:customer, customer_id: "cus_Q1n", product_id: product.external_id, user_id: user.id)
  end
  fab!(:customer2) do
    Fabricate(:customer, customer_id: "cus_Q1n", product_id: product.external_id, user_id: user.id)
  end
  fab!(:subscription) do
    Fabricate(:subscription, customer_id: customer.id, external_id: "sub_10z", status: "active")
  end
  fab!(:subscription2) do
    Fabricate(:subscription, customer_id: customer2.id, external_id: "sub_32b", status: "canceled")
  end
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:product_subscriptions_page) { PageObjects::Pages::AdminSubscriptionProduct.new }
  let(:admin_subscriptions_page) { PageObjects::Pages::AdminSubscriptionSubscription.new }
  let(:user_billing_subscriptions_page) { PageObjects::Pages::UserBillingSubscription.new }

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

    plans_json =
      File.read(
        Rails.root.join(
          "plugins",
          "discourse-subscriptions",
          "spec",
          "fixtures",
          "json",
          "stripe-price-list.json",
        ),
      )

    subscriptions_json =
      File.read(
        Rails.root.join(
          "plugins",
          "discourse-subscriptions",
          "spec",
          "fixtures",
          "json",
          "stripe-subscription-list.json",
        ),
      )

    ::Stripe::Product.stubs(:list).returns({ data: [one_product] })
    ::Stripe::Product.stubs(:delete).returns({ id: "prod_OiK" })
    ::Stripe::Product.stubs(:retrieve).returns(one_product)
    ::Stripe::Price.stubs(:list).returns(JSON.parse(plans_json, symbolize_names: true))
    ::Stripe::Subscription.stubs(:list).returns(
      JSON.parse(subscriptions_json, symbolize_names: true),
    )
  end

  it "shows active and canceled subscriptions for admins" do
    sign_in(admin)

    active_subscription_row =
      admin_subscriptions_page.visit_subscriptions.subscription_row("sub_10z")
    expect(active_subscription_row).to have_text("active")
    canceled_subscription_row =
      admin_subscriptions_page.visit_subscriptions.subscription_row("sub_32b")
    expect(canceled_subscription_row).to have_text("canceled")
  end

  it "shows active and canceled subscriptions for users" do
    sign_in(user)

    user_billing_subscriptions_page.visit_subscriptions
    user_billing_subscriptions_page.has_number_of_subscriptions?(2)

    active_subscription_row = user_billing_subscriptions_page.subscription_row("sub_10z")
    expect(active_subscription_row).to have_text("active")
    canceled_subscription_row = user_billing_subscriptions_page.subscription_row("sub_32b")
    expect(canceled_subscription_row).to have_text("canceled")
  end
end
