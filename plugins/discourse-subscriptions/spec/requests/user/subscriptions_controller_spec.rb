# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseSubscriptions::User::SubscriptionsController do
  before { SiteSetting.discourse_subscriptions_enabled = true }

  def create_price(id, product)
    price = { id: id, product: product }
    def price.id
      self[:id]
    end
    price
  end

  it "is a subclass of ApplicationController" do
    expect(DiscourseSubscriptions::User::SubscriptionsController < ::ApplicationController).to eq(
      true,
    )
  end

  context "when not authenticated" do
    it "does not get the subscriptions" do
      ::Stripe::Customer.expects(:list).never
      get "/s/user/subscriptions.json"
    end

    it "does not destroy a subscription" do
      ::Stripe::Subscription.expects(:delete).never
      patch "/s/user/subscriptions/sub_12345.json"
    end

    it "doesn't update payment method for subscription" do
      ::Stripe::Subscription.expects(:update).never
      ::Stripe::PaymentMethod.expects(:attach).never
      put "/s/user/subscriptions/sub_12345.json", params: { payment_method: "pm_abc123abc" }
    end
  end

  context "when authenticated" do
    let(:user) { Fabricate(:user, email: "beanie@example.com") }
    let(:customer) do
      Fabricate(:customer, user_id: user.id, customer_id: "cus_23456", product_id: "prod_123")
    end

    before do
      sign_in(user)
      Fabricate(:subscription, customer_id: customer.id, external_id: "sub_10z")
    end

    describe "index" do
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

      it "gets subscriptions" do
        ::Stripe::Price.stubs(:list).returns(JSON.parse(plans_json, symbolize_names: true))

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

        ::Stripe::Subscription.stubs(:list).returns(
          JSON.parse(subscriptions_json, symbolize_names: true),
        )

        get "/s/user/subscriptions.json"

        subscription = JSON.parse(response.body, symbolize_names: true).first

        expect(subscription[:id]).to eq("sub_10z")
        expect(subscription[:items][:data][0][:plan][:id]).to eq("price_1OrmlvEYXaQnncShNahrpKvA")
        expect(subscription[:product][:name]).to eq("Exclusive Access")
      end

      it "aggregates prices from multiple pages using pagination logic" do
        subscription_data = { id: "sub_10z", items: { data: [{ price: { id: "price_200" } }] } }
        ::Stripe::Subscription
          .stubs(:list)
          .with(customer: "cus_23456", status: "all")
          .returns({ data: [subscription_data] })

        # Build the first page of 100 prices that do NOT include the desired price.
        prices_page_1 =
          (1..100).map do |i|
            create_price("price_#{i}", { id: "prod_dummy", name: "Dummy Product #{i}" })
          end

        # Second page containing the desired price.
        prices_page_2 = [create_price("price_200", { id: "prod_200", name: "Matching Product" })]

        ::Stripe::Price
          .expects(:list)
          .with(has_entries(limit: 100, expand: ["data.product"]))
          .returns({ data: prices_page_1, has_more: true })

        ::Stripe::Price
          .expects(:list)
          .with(has_entries(limit: 100, expand: ["data.product"], starting_after: "price_100"))
          .returns({ data: prices_page_2, has_more: false })

        get "/s/user/subscriptions.json"
        result = JSON.parse(response.body, symbolize_names: true)
        subscription = result.first

        expect(subscription[:id]).to eq("sub_10z")
        expect(subscription[:plan][:id]).to eq("price_200")
        expect(subscription[:product][:id]).to eq("prod_200")
        expect(subscription[:product][:name]).to eq("Matching Product")
      end
    end

    describe "update" do
      it "updates the payment method for subscription" do
        ::Stripe::Subscription.expects(:update).once
        ::Stripe::PaymentMethod.expects(:attach).once
        put "/s/user/subscriptions/sub_10z.json", params: { payment_method: "pm_abc123abc" }
      end
    end
  end
end
