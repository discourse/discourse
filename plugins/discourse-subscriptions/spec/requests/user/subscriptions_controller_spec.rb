# frozen_string_literal: true

RSpec.describe DiscourseSubscriptions::User::SubscriptionsController, :setup_stripe_mock do
  before { setup_discourse_subscriptions }

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
    fab!(:user)

    before { sign_in(user) }

    describe "index" do
      it "gets subscriptions with plan and product details" do
        stripe_product = Stripe::Product.construct_from(id: "prod_test", name: "User Sub Product")

        stripe_price =
          Stripe::Price.construct_from(
            id: "price_test",
            unit_amount: 1000,
            currency: "usd",
            recurring: {
              interval: "month",
            },
            product: stripe_product,
          )

        stripe_subscription =
          Stripe::Subscription.construct_from(
            id: "sub_test",
            status: "active",
            items: {
              data: [{ price: { id: "price_test" } }],
            },
          )

        dc =
          Fabricate(:customer, user_id: user.id, customer_id: "cus_test", product_id: "prod_test")
        Fabricate(:subscription, customer_id: dc.id, external_id: "sub_test")

        ::Stripe::Price.stubs(:list).returns(
          Stripe::ListObject.construct_from(data: [stripe_price], has_more: false),
        )
        ::Stripe::Subscription
          .stubs(:list)
          .with(customer: "cus_test", status: "all")
          .returns(Stripe::ListObject.construct_from(data: [stripe_subscription]))

        get "/s/user/subscriptions.json"
        expect(response.status).to eq(200)

        result = response.parsed_body
        expect(result.length).to eq(1)
        expect(result.first["id"]).to eq("sub_test")
        expect(result.first["status"]).to eq("active")
        expect(result.first["product"]["name"]).to eq("User Sub Product")
      end
    end

    describe "update" do
      it "updates the payment method for subscription" do
        dc =
          Fabricate(:customer, user_id: user.id, customer_id: "cus_test", product_id: "prod_test")
        Fabricate(:subscription, customer_id: dc.id, external_id: "sub_test")

        ::Stripe::PaymentMethod
          .stubs(:attach)
          .with("pm_test", { customer: "cus_test" })
          .returns(Stripe::PaymentMethod.construct_from(id: "pm_test"))

        ::Stripe::Subscription
          .stubs(:update)
          .with("sub_test", { default_payment_method: "pm_test" })
          .returns(Stripe::Subscription.construct_from(id: "sub_test"))

        put "/s/user/subscriptions/sub_test.json", params: { payment_method: "pm_test" }

        expect(response.status).to eq(200)
      end
    end
  end

  context "when authenticated as another user" do
    fab!(:user_1, :user)
    fab!(:user_2, :user)
    fab!(:customer) { Fabricate(:customer, user_id: user_1.id, customer_id: "001") }
    fab!(:subscription) { Fabricate(:subscription, customer_id: customer.id, external_id: "abc") }

    before { sign_in(user_2) }

    describe "destroy" do
      it "does not allow user to cancel a subscription that is not theirs" do
        ::Stripe::Subscription.expects(:update).never

        delete "/s/user/subscriptions/abc.json"

        expect(response.status).to eq(404)
      end
    end

    describe "update" do
      it "does not allow user to update a subscription that is not theirs" do
        ::Stripe::PaymentMethod.expects(:attach).never
        ::Stripe::Subscription.expects(:update).never

        put "/s/user/subscriptions/abc.json", params: { payment_method: "x" }

        expect(response.status).to eq(404)
      end
    end
  end
end
