# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseSubscriptions::Admin::SubscriptionsController do
  before { SiteSetting.discourse_subscriptions_enabled = true }

  it "is a subclass of AdminController" do
    expect(DiscourseSubscriptions::Admin::SubscriptionsController < ::Admin::AdminController).to eq(
      true,
    )
  end

  let(:user) { Fabricate(:user) }
  let(:customer) do
    Fabricate(:customer, user_id: user.id, customer_id: "c_123", product_id: "pr_34578")
  end

  before do
    Fabricate(:subscription, external_id: "sub_12345", customer_id: customer.id)
    Fabricate(:subscription, external_id: "sub_77777", customer_id: customer.id)
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
    let(:admin) { Fabricate(:admin) }

    before { sign_in(admin) }

    describe "index" do
      before do
        SiteSetting.discourse_subscriptions_public_key = "public-key"
        SiteSetting.discourse_subscriptions_secret_key = "secret-key"
      end

      it "gets the subscriptions and products" do
        ::Stripe::Subscription
          .expects(:list)
          .with(expand: ["data.plan.product"], limit: 10, starting_after: nil, status: "all")
          .returns(has_more: false, data: [{ id: "sub_12345" }, { id: "sub_nope" }])
        get "/s/admin/subscriptions.json"
        subscriptions = response.parsed_body["data"][0]["id"]

        expect(response.status).to eq(200)
        expect(subscriptions).to eq("sub_12345")
      end

      it "handles starting at a different point in the set" do
        ::Stripe::Subscription
          .expects(:list)
          .with(expand: ["data.plan.product"], limit: 10, starting_after: "sub_nope", status: "all")
          .returns(has_more: false, data: [{ id: "sub_77777" }, { id: "sub_yepnoep" }])
        get "/s/admin/subscriptions.json", params: { last_record: "sub_nope" }
        subscriptions = response.parsed_body["data"][0]["id"]

        expect(response.status).to eq(200)
        expect(subscriptions).to eq("sub_77777")
      end
    end

    describe "destroy" do
      let(:group) { Fabricate(:group, name: "subscribers") }

      before { group.add(user) }

      it "deletes a customer" do
        ::Stripe::Subscription
          .expects(:cancel)
          .with("sub_12345")
          .returns(plan: { product: "pr_34578" }, customer: "c_123")

        # We don't want to delete the customer record. The webhook hook will update the status instead.
        expect { delete "/s/admin/subscriptions/sub_12345.json" }.not_to change {
          DiscourseSubscriptions::Customer.count
        }
      end

      it "removes the user from the group" do
        ::Stripe::Subscription
          .expects(:cancel)
          .with("sub_12345")
          .returns(
            plan: {
              product: "pr_34578",
              metadata: {
                group_name: "subscribers",
              },
            },
            customer: "c_123",
          )

        expect { delete "/s/admin/subscriptions/sub_12345.json" }.to change {
          user.groups.count
        }.by(-1)
      end

      it "does not remove the user from the group" do
        ::Stripe::Subscription
          .expects(:cancel)
          .with("sub_12345")
          .returns(
            plan: {
              product: "pr_34578",
              metadata: {
                group_name: "group_does_not_exist",
              },
            },
            customer: "c_123",
          )

        expect { delete "/s/admin/subscriptions/sub_12345.json" }.not_to change {
          user.groups.count
        }
      end

      it "refunds if params[:refund] present" do
        ::Stripe::Subscription
          .expects(:cancel)
          .with("sub_12345")
          .returns(plan: { product: "pr_34578" }, customer: "c_123")
        ::Stripe::Subscription
          .expects(:retrieve)
          .with("sub_12345")
          .returns(latest_invoice: "in_123")
        ::Stripe::Invoice.expects(:retrieve).with("in_123").returns(payment_intent: "pi_123")
        ::Stripe::Refund.expects(:create).with({ payment_intent: "pi_123" })

        delete "/s/admin/subscriptions/sub_12345.json", params: { refund: true }
      end
    end
  end
end
