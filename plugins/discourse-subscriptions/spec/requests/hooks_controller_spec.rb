# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseSubscriptions::HooksController do
  before do
    SiteSetting.discourse_subscriptions_webhook_secret = "zascharoo"
    SiteSetting.discourse_subscriptions_enabled = true
  end

  it "constructs a webhook event" do
    payload = "we-want-a-shrubbery"
    headers = { HTTP_STRIPE_SIGNATURE: "stripe-webhook-signature" }

    ::Stripe::Webhook
      .expects(:construct_event)
      .with("we-want-a-shrubbery", "stripe-webhook-signature", "zascharoo")
      .returns(type: "something")

    post "/s/hooks.json", params: payload, headers: headers

    expect(response.status).to eq 200
  end

  describe "event types" do
    let(:user) { Fabricate(:user) }
    let(:customer) do
      Fabricate(:customer, customer_id: "c_575768", product_id: "p_8654", user_id: user.id)
    end
    let!(:subscription) do
      Fabricate(:subscription, external_id: "sub_12345", customer_id: customer.id, status: nil)
    end
    let(:group) { Fabricate(:group, name: "subscribers-group") }

    let(:event_data) do
      {
        object: {
          customer: customer.customer_id,
          plan: {
            product: customer.product_id,
            metadata: {
              group_name: group.name,
            },
          },
        },
      }
    end

    let(:customer_subscription_deleted_data) do
      {
        object: {
          id: subscription.external_id,
          customer: customer.customer_id,
          plan: {
            product: customer.product_id,
            metadata: {
              group_name: group.name,
            },
          },
          status: "canceled",
        },
      }
    end

    let(:checkout_session_completed_data) do
      {
        object: {
          id: "cs_test_a1ENei5A9TGOaEketyV5qweiQR5CyJWHT5j8T3HheQY3uah3RxzKttVUKZ",
          object: "checkout.session",
          customer: customer.customer_id,
          customer_email: user.email,
          invoice: "in_1P9b7iEYXaQnncSh81AQtuHD",
          metadata: {
          },
          mode: "subscription",
          payment_status: "paid",
          status: "complete",
          submit_type: nil,
          subscription: "sub_1P9b7iEYXaQnncSh3H3G9d2Y",
          success_url: "http://localhost:4200/my/billing/subscriptions",
          url: nil,
        },
      }
    end

    let(:checkout_session_completed_data_one_off) do
      {
        object: {
          id: "cs_test_a1ENei5A9TGOaEketyV5qweiQR5CyJWHT5j8T3HheQY3uah3RxzKttVUKZ",
          object: "checkout.session",
          customer: nil,
          customer_email: user.email,
          invoice: nil,
          metadata: {
          },
          mode: "subscription",
          payment_intent: "pi_3PsohkGHcn",
          payment_status: "paid",
          status: "complete",
          submit_type: nil,
          subscription: nil,
          success_url: "http://localhost:4200/my/billing/subscriptions",
          url: nil,
        },
      }
    end

    let(:checkout_session_completed_bad_data) do
      {
        object: {
          id: "cs_test_a1ENei5A9TGOaEketyV5qweiQR5CyJWHT5j8T3HheQY3uah3RxzKttVUKZ",
          object: "checkout.session",
          customer: nil,
          customer_email: nil,
          invoice: "in_1P9b7iEYXaQnncSh81AQtuHD",
          metadata: {
          },
          mode: "subscription",
          payment_status: "paid",
          status: "complete",
          submit_type: nil,
          subscription: nil,
          success_url: "http://localhost:4200/my/billing/subscriptions",
          url: nil,
        },
      }
    end

    let(:list_line_items_data) do
      {
        data: [
          {
            id: "li_1P9YlFEYXaQnncShFBl7r0na",
            object: "item",
            description: "Exclusive Access",
            price: {
              id: "price_1OrmlvEYXaQnncShNahrpKvA",
              metadata: {
                group_name: group.name,
                trial_period_days: "0",
              },
              nickname: "EA1",
              product: "prod_PhB6IpGhEX14Hi",
            },
          },
        ],
      }
    end

    describe "checkout.session.completed" do
      before do
        event = { type: "checkout.session.completed", data: checkout_session_completed_data }
        ::Stripe::Checkout::Session
          .stubs(:list_line_items)
          .with(checkout_session_completed_data[:object][:id], { limit: 1 })
          .returns(list_line_items_data)

        ::Stripe::Subscription
          .stubs(:update)
          .with(
            checkout_session_completed_data[:object][:subscription],
            { metadata: { user_id: user.id, username: user.username } },
          )
          .returns(
            {
              id: checkout_session_completed_data[:object][:subscription],
              object: "subscription",
              metadata: {
                user_id: user.id.to_s,
                username: user.username,
              },
            },
          )

        ::Stripe::Webhook.stubs(:construct_event).returns(event)
      end

      it "is successfull" do
        post "/s/hooks.json"
        expect(response.status).to eq 200
      end

      describe "completing the subscription" do
        it "adds the user to the group when completing the transaction" do
          expect { post "/s/hooks.json" }.to change { user.groups.count }.by(1)

          expect(response.status).to eq 200
        end
      end
    end

    describe "checkout.session.completed with bad data" do
      before do
        event = { type: "checkout.session.completed", data: checkout_session_completed_bad_data }
        ::Stripe::Checkout::Session
          .stubs(:list_line_items)
          .with(checkout_session_completed_data[:object][:id], { limit: 1 })
          .returns(list_line_items_data)

        ::Stripe::Webhook.stubs(:construct_event).returns(event)
        ::Stripe::Customer.stubs(:create).returns(id: "cus_1234")
      end

      it "is returns 422" do
        post "/s/hooks.json"
        expect(response.status).to eq 422
      end
    end

    describe "checkout.session.completed for one-off purchase" do
      before do
        event = {
          type: "checkout.session.completed",
          data: checkout_session_completed_data_one_off,
        }
        ::Stripe::Checkout::Session
          .stubs(:list_line_items)
          .with(checkout_session_completed_data[:object][:id], { limit: 1 })
          .returns(list_line_items_data)

        ::Stripe::Webhook.stubs(:construct_event).returns(event)
        ::Stripe::Customer.stubs(:create).returns(id: "cus_1234")
      end

      it "is returns 200" do
        expect { post "/s/hooks.json" }.to change { user.groups.count }.by(1)
        expect(response.status).to eq 200
      end
    end

    describe "checkout.session.completed with anonymous user" do
      before do
        checkout_session_completed_bad_data[:object][:customer_email] = "anonymous@example.com"
        data = checkout_session_completed_bad_data
        event = { type: "checkout.session.completed", data: data }
        ::Stripe::Checkout::Session
          .stubs(:list_line_items)
          .with(checkout_session_completed_data[:object][:id], { limit: 1 })
          .returns(list_line_items_data)

        ::Stripe::Webhook.stubs(:construct_event).returns(event)
        ::Stripe::Customer.stubs(:create).returns(id: "cus_1234")
      end

      it "is returns 422" do
        post "/s/hooks.json"
        expect(response.status).to eq 422
      end
    end

    describe "checkout.session.completed with no customer email" do
      before do
        checkout_session_completed_bad_data[:object][:customer_email] = nil
        data = checkout_session_completed_bad_data
        event = { type: "checkout.session.completed", data: data }
        ::Stripe::Checkout::Session
          .stubs(:list_line_items)
          .with(checkout_session_completed_data[:object][:id], { limit: 1 })
          .returns(list_line_items_data)

        ::Stripe::Webhook.stubs(:construct_event).returns(event)
      end

      it "is returns 422" do
        post "/s/hooks.json"
        expect(response.status).to eq 422
      end
    end

    describe "customer.subscription.updated" do
      before do
        event = { type: "customer.subscription.updated", data: event_data }

        ::Stripe::Webhook.stubs(:construct_event).returns(event)
      end

      it "is successfull" do
        post "/s/hooks.json"
        expect(response.status).to eq 200
      end

      describe "completing the subscription" do
        it "does not add the user to the group" do
          event_data[:object][:status] = "incomplete"
          event_data[:previous_attributes] = { status: "incomplete" }

          expect { post "/s/hooks.json" }.not_to change { user.groups.count }

          expect(response.status).to eq 200
        end

        it "does not add the user to the group" do
          event_data[:object][:status] = "incomplete"
          event_data[:previous_attributes] = { status: "something-else" }

          expect { post "/s/hooks.json" }.not_to change { user.groups.count }

          expect(response.status).to eq 200
        end

        it "adds the user to the group when completing the transaction" do
          event_data[:object][:status] = "complete"
          event_data[:previous_attributes] = { status: "incomplete" }

          expect { post "/s/hooks.json" }.to change { user.groups.count }.by(1)

          expect(response.status).to eq 200
        end

        it "adds the user to the group when status is active" do
          event_data[:object][:status] = "active"

          expect { post "/s/hooks.json" }.to change { user.groups.count }.by(1)

          expect(response.status).to eq 200
        end
      end
    end

    describe "customer.subscription.deleted" do
      before do
        event = { type: "customer.subscription.deleted", data: customer_subscription_deleted_data }

        ::Stripe::Webhook.stubs(:construct_event).returns(event)

        group.add(user)
      end

      it "deletes the customer" do
        expect { post "/s/hooks.json" }.to change {
          DiscourseSubscriptions::Subscription.where(status: "canceled").count
        }.by(+1)

        expect(response.status).to eq 200
      end

      it "removes the user from the group" do
        expect { post "/s/hooks.json" }.to change { user.groups.count }.by(-1)

        expect(response.status).to eq 200
      end
    end
  end
end
