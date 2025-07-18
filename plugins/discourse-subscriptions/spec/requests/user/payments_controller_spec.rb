# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseSubscriptions::User::PaymentsController do
  before { SiteSetting.discourse_subscriptions_enabled = true }

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
    let(:user) { Fabricate(:user, email: "zasch@example.com") }

    before do
      sign_in(user)
      Fabricate(:customer, customer_id: "c_345678", user_id: user.id)
      Fabricate(:product, external_id: "prod_8675309")
      Fabricate(:product, external_id: "prod_8675310")
    end

    it "gets payment intents" do
      created_time = Time.now
      ::Stripe::Invoice
        .expects(:list)
        .with(customer: "c_345678")
        .returns(
          data: [
            { id: "inv_900007", lines: { data: [plan: { product: "prod_8675309" }] } },
            { id: "inv_900008", lines: { data: [plan: { product: "prod_8675310" }] } },
            { id: "inv_900008", lines: { data: [plan: { product: "prod_8675310" }] } },
          ],
        )

      ::Stripe::PaymentIntent
        .expects(:list)
        .with(customer: "c_345678")
        .returns(
          data: [
            { id: "pi_900008", invoice: "inv_900008", created: created_time },
            { id: "pi_900008", invoice: "inv_900008", created: created_time },
            { id: "pi_900007", invoice: "inv_900007", created: Time.now },
            { id: "pi_007", invoice: "inv_007", created: Time.now },
          ],
        )

      get "/s/user/payments.json"

      parsed_body = response.parsed_body
      invoice = parsed_body[0]["invoice"]

      expect(invoice).to eq("inv_900007")
      expect(parsed_body.count).to eq(2)
    end

    it "gets pricing table one-off purchases" do
      ::Stripe::Invoice.expects(:list).with(customer: "c_345678").returns(data: [])

      ::Stripe::PaymentIntent
        .expects(:list)
        .with(customer: "c_345678")
        .returns(data: [{ id: "pi_900010", invoice: nil, created: Time.now }])

      get "/s/user/payments.json"

      parsed_body = response.parsed_body

      expect(parsed_body.count).to eq(1)
    end

    it "gets pricing table one-off purchases that show up as related guest payments" do
      SiteSetting.discourse_subscriptions_pricing_table_enabled = true
      ::Stripe::Invoice.expects(:list).with(customer: "c_345678").returns(data: [])

      ::Stripe::PaymentIntent.expects(:list).with(customer: "c_345678").returns(data: [])

      ::Stripe::Charge
        .expects(:list)
        .with(limit: 100, starting_after: nil, expand: ["data.payment_intent"])
        .returns(
          data: [
            {
              id: "ch_1HtGz2GHcn71qeAp4YjA2oB4",
              amount: 2000,
              currency: "usd",
              billing_details: {
                email: user.email,
              },
              customer: nil, # guest payment
              payment_intent: "pi_1HtGz1GHcn71qeApT9N2Cjln",
              created: Time.now.to_i,
            },
            {
              id: "ch_2HtGz2GHcn71qeAp4YjA2oB4",
              amount: 2000,
              currency: "usd",
              billing_details: {
                email: "zxcv@example.com",
              },
              customer: nil, # different guest
              payment_intent: "pi_2HtGz1GHcn71qeApT9N2Cjln",
              created: Time.now.to_i,
            },
            {
              id: "ch_1HtGz3GHcn71qeAp5YjA2oC5",
              amount: 3000,
              currency: "usd",
              billing_details: {
                email: "fdsa@example.com",
              },
              customer: "cus_1234", # This is not a guest payment
              payment_intent: "pi_3HtGz2GHcn71qeApT9N2Cjln",
              created: Time.now.to_i,
            },
          ],
        )

      get "/s/user/payments.json"

      parsed_body = response.parsed_body

      # Validate that only guest payments with the specified email are returned
      expect(parsed_body.count).to eq(1)
      expect(parsed_body.first["id"]).to eq("ch_1HtGz2GHcn71qeAp4YjA2oB4")
      expect(parsed_body.first["customer"]).to be_nil
    end
  end
end
