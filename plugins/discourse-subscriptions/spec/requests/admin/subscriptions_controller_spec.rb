# frozen_string_literal: true

RSpec.describe DiscourseSubscriptions::Admin::SubscriptionsController, :setup_stripe_mock do
  before { setup_discourse_subscriptions }

  it "is a subclass of AdminController" do
    expect(DiscourseSubscriptions::Admin::SubscriptionsController < ::Admin::AdminController).to eq(
      true,
    )
  end

  context "when unauthenticated" do
    it "does nothing" do
      ::Stripe::Subscription.expects(:list).never
      get "/s/admin/subscriptions.json"
      expect(response.status).to eq(404)
    end

    it "does not destroy a subscription" do
      ::Stripe::Subscription.expects(:delete).never
      patch "/s/admin/subscriptions/sub_12345.json"
    end
  end

  context "when authenticated" do
    fab!(:user)
    fab!(:admin)

    before do
      sign_in(admin)
      SiteSetting.discourse_subscriptions_public_key = "public-key"
    end

    describe "index" do
      it "gets the subscriptions" do
        product = ::Stripe::Product.create(name: "Sub List Product", type: "service")
        price =
          ::Stripe::Price.create(
            product: product.id,
            unit_amount: 1000,
            currency: "usd",
            recurring: {
              interval: "month",
            },
          )
        customer =
          ::Stripe::Customer.create(
            email: "test@example.com",
            source: StripeMock.generate_card_token,
          )

        sub1 = ::Stripe::Subscription.create(customer: customer.id, items: [{ price: price.id }])
        sub2 = ::Stripe::Subscription.create(customer: customer.id, items: [{ price: price.id }])

        dc =
          Fabricate(:customer, user_id: user.id, customer_id: customer.id, product_id: product.id)
        Fabricate(:subscription, external_id: sub1.id, customer_id: dc.id)
        Fabricate(:subscription, external_id: sub2.id, customer_id: dc.id)

        get "/s/admin/subscriptions.json"

        expect(response.status).to eq(200)
        data = response.parsed_body["data"]
        ids = data.map { |d| d["id"] }
        expect(ids).to include(sub1.id, sub2.id)
        expect(data.find { |d| d["id"] == sub1.id }["status"]).to eq("active")
        expect(data.find { |d| d["id"] == sub2.id }["status"]).to eq("active")
      end
    end

    describe "destroy" do
      it "cancels a subscription" do
        product_id = "prod_cancel1"
        customer_id = "cus_cancel1"

        cancelled_sub =
          Stripe::Subscription.construct_from(
            id: "sub_cancel1",
            status: "canceled",
            plan: {
              id: "price_cancel1",
              product: product_id,
              metadata: {
                group_name: "",
              },
            },
            customer: customer_id,
          )

        ::Stripe::Subscription.stubs(:cancel).with("sub_cancel1").returns(cancelled_sub)

        dc =
          Fabricate(:customer, user_id: user.id, customer_id: customer_id, product_id: product_id)
        Fabricate(:subscription, external_id: "sub_cancel1", customer_id: dc.id)

        expect { delete "/s/admin/subscriptions/sub_cancel1.json" }.not_to change {
          DiscourseSubscriptions::Customer.count
        }
        expect(response.status).to eq(200)
      end

      it "removes the user from the group" do
        group = Fabricate(:group, name: "sub-cancel-group")
        group.add(user)

        product_id = "prod_cancel_group1"
        customer_id = "cus_cancel_group1"

        cancelled_sub =
          Stripe::Subscription.construct_from(
            id: "sub_cancel_group1",
            status: "canceled",
            plan: {
              id: "price_cancel_group1",
              product: product_id,
              metadata: {
                group_name: "sub-cancel-group",
              },
            },
            customer: customer_id,
          )

        ::Stripe::Subscription.stubs(:cancel).with("sub_cancel_group1").returns(cancelled_sub)

        dc =
          Fabricate(:customer, user_id: user.id, customer_id: customer_id, product_id: product_id)
        Fabricate(:subscription, external_id: "sub_cancel_group1", customer_id: dc.id)

        expect { delete "/s/admin/subscriptions/sub_cancel_group1.json" }.to change {
          user.groups.count
        }.by(-1)
      end

      it "does not remove the user from the group when group doesn't match" do
        group = Fabricate(:group, name: "unrelated-group")
        group.add(user)

        product_id = "prod_cancel_nomatch1"
        customer_id = "cus_cancel_nomatch1"

        cancelled_sub =
          Stripe::Subscription.construct_from(
            id: "sub_cancel_nomatch1",
            status: "canceled",
            plan: {
              id: "price_cancel_nomatch1",
              product: product_id,
              metadata: {
                group_name: "nonexistent-group",
              },
            },
            customer: customer_id,
          )

        ::Stripe::Subscription.stubs(:cancel).with("sub_cancel_nomatch1").returns(cancelled_sub)

        dc =
          Fabricate(:customer, user_id: user.id, customer_id: customer_id, product_id: product_id)
        Fabricate(:subscription, external_id: "sub_cancel_nomatch1", customer_id: dc.id)

        expect { delete "/s/admin/subscriptions/sub_cancel_nomatch1.json" }.not_to change {
          user.groups.count
        }
      end

      it "does not refund when refund param is the string 'false'" do
        ::Stripe::Subscription.expects(:retrieve).never
        ::Stripe::Refund.expects(:create).never

        product_id = "prod_norefund1"
        customer_id = "cus_norefund1"

        cancelled_sub =
          Stripe::Subscription.construct_from(
            id: "sub_norefund1",
            status: "canceled",
            plan: {
              id: "price_norefund1",
              product: product_id,
              metadata: {
                group_name: "",
              },
            },
            customer: customer_id,
          )

        ::Stripe::Subscription.stubs(:cancel).with("sub_norefund1").returns(cancelled_sub)

        dc =
          Fabricate(:customer, user_id: user.id, customer_id: customer_id, product_id: product_id)
        Fabricate(:subscription, external_id: "sub_norefund1", customer_id: dc.id)

        delete "/s/admin/subscriptions/sub_norefund1.json", params: { refund: "false" }
      end

      it "refunds if params[:refund] present" do
        product_id = "prod_refund1"
        customer_id = "cus_refund1"

        cancelled_sub =
          Stripe::Subscription.construct_from(
            id: "sub_refund1",
            status: "canceled",
            plan: {
              id: "price_refund1",
              product: product_id,
              metadata: {
                group_name: "",
              },
            },
            customer: customer_id,
          )

        retrieved_sub =
          Stripe::Subscription.construct_from(id: "sub_refund1", latest_invoice: "in_refund1")

        invoice = Stripe::Invoice.construct_from(id: "in_refund1", payment_intent: "pi_refund1")

        refund = Stripe::Refund.construct_from(id: "re_refund1", status: "succeeded")

        ::Stripe::Subscription.stubs(:retrieve).with("sub_refund1").returns(retrieved_sub)
        ::Stripe::Invoice.stubs(:retrieve).with("in_refund1").returns(invoice)
        ::Stripe::Refund.stubs(:create).with({ payment_intent: "pi_refund1" }).returns(refund)
        ::Stripe::Subscription.stubs(:cancel).with("sub_refund1").returns(cancelled_sub)

        dc =
          Fabricate(:customer, user_id: user.id, customer_id: customer_id, product_id: product_id)
        Fabricate(:subscription, external_id: "sub_refund1", customer_id: dc.id)

        delete "/s/admin/subscriptions/sub_refund1.json", params: { refund: true }
        expect(response.status).to eq(200)
      end
    end
  end
end
