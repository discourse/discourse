# frozen_string_literal: true

RSpec.describe DiscourseSubscriptions::User::PaymentsController, :setup_stripe_mock do
  before { setup_discourse_subscriptions }

  it "is a subclass of ApplicationController" do
    expect(DiscourseSubscriptions::User::PaymentsController < ::ApplicationController).to eq(true)
  end

  context "when not authenticated" do
    it "does not get the payment intents" do
      ::Stripe::PaymentIntent.expects(:list).never
      get "/s/user/payments.json"
      expect(response.status).to eq(403)
    end
  end

  context "when authenticated" do
    fab!(:user)

    before { sign_in(user) }

    it "gets payment intents from invoices" do
      Fabricate(:product, external_id: "prod_test")
      Fabricate(:customer, customer_id: "cus_test", user_id: user.id)

      invoice =
        Stripe::Invoice.construct_from(
          id: "in_test",
          lines: {
            data: [{ price: { product: "prod_test" }, plan: nil }],
          },
        )

      payment_intent =
        Stripe::PaymentIntent.construct_from(
          id: "pi_test",
          amount: 1000,
          invoice: "in_test",
          created: 1_000_000,
        )

      ::Stripe::Invoice
        .stubs(:list)
        .with(customer: "cus_test")
        .returns(Stripe::ListObject.construct_from(data: [invoice]))
      ::Stripe::PaymentIntent
        .stubs(:list)
        .with(customer: "cus_test")
        .returns(Stripe::ListObject.construct_from(data: [payment_intent]))

      get "/s/user/payments.json"
      expect(response.status).to eq(200)

      data = response.parsed_body
      expect(data.length).to be >= 1
      expect(data.first["id"]).to start_with("pi_")
      expect(data.first["amount"]).to eq(1000)
    end

    it "gets pricing table guest charges" do
      SiteSetting.discourse_subscriptions_pricing_table_enabled = true

      Fabricate(:customer, customer_id: "cus_guest_test", user_id: user.id)

      ::Stripe::Invoice
        .stubs(:list)
        .with(customer: "cus_guest_test")
        .returns(Stripe::ListObject.construct_from(data: []))
      ::Stripe::PaymentIntent
        .stubs(:list)
        .with(customer: "cus_guest_test")
        .returns(Stripe::ListObject.construct_from(data: []))

      guest_charge =
        Stripe::Charge.construct_from(
          id: "ch_guest_test",
          billing_details: {
            email: user.email,
          },
          customer: nil,
          created: 1_000_000,
        )

      ::Stripe::Charge.stubs(:list).returns(Stripe::ListObject.construct_from(data: [guest_charge]))

      get "/s/user/payments.json"
      expect(response.status).to eq(200)
    end
  end
end
