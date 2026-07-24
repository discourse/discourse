# frozen_string_literal: true

RSpec.describe DiscourseSubscriptions::HooksController do
  before do
    SiteSetting.discourse_subscriptions_webhook_secret = "zascharoo"
    SiteSetting.discourse_subscriptions_secret_key = "secret-key"
    SiteSetting.discourse_subscriptions_enabled = true
  end

  it "rejects webhooks when webhook secret is blank" do
    SiteSetting.discourse_subscriptions_webhook_secret = ""
    post "/s/hooks.json", params: "{}", headers: { HTTP_STRIPE_SIGNATURE: "t=1,v1=abc" }
    expect(response.status).to eq 403
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
    let(:client_reference_id) do
      user.signed_id(
        expires_in: DiscourseSubscriptions::CHECKOUT_SESSION_USER_REFERENCE_EXPIRES_IN,
        purpose: DiscourseSubscriptions::CHECKOUT_SESSION_USER_REFERENCE_PURPOSE,
      )
    end

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
          client_reference_id: client_reference_id,
          invoice: "in_1P9b7iEYXaQnncSh81AQtuHD",
          metadata: {
          },
          mode: "subscription",
          payment_status: "paid",
          status: "complete",
          submit_type: nil,
          subscription: "sub_1P9b7iEYXaQnncSh3H3G9d2Y",
          success_url: "http://localhost:3000/my/billing/subscriptions",
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
          client_reference_id: client_reference_id,
          invoice: nil,
          metadata: {
          },
          mode: "subscription",
          payment_intent: "pi_3PsohkGHcn",
          payment_status: "paid",
          status: "complete",
          submit_type: nil,
          subscription: nil,
          success_url: "http://localhost:3000/my/billing/subscriptions",
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
          success_url: "http://localhost:3000/my/billing/subscriptions",
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
          .with(
            checkout_session_completed_data[:object][:id],
            { limit: 1 },
            DiscourseSubscriptions::Stripe.request_opts,
          )
          .returns(list_line_items_data)

        ::Stripe::Subscription
          .stubs(:update)
          .with(
            checkout_session_completed_data[:object][:subscription],
            { metadata: { user_id: user.id, username: user.username } },
            DiscourseSubscriptions::Stripe.request_opts,
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

      it "is successful" do
        post "/s/hooks.json"
        expect(response.status).to eq 200
      end

      it "accepts a secondary email that belongs to the signed user" do
        secondary_email = "secondary-#{user.id}@example.com"
        ::UserEmail.create!(user: user, email: secondary_email, primary: false)
        data = checkout_session_completed_data.deep_dup
        data[:object][:customer_email] = secondary_email
        ::Stripe::Webhook.stubs(:construct_event).returns(
          type: "checkout.session.completed",
          data: data,
        )

        expect { post "/s/hooks.json" }.to change { user.reload.groups.count }.by(1)

        aggregate_failures do
          expect(response.status).to eq(200)
          expect(group.reload.users).to contain_exactly(user)
          expect(DiscourseSubscriptions::Customer.order(:id).last.user_id).to eq(user.id)
        end
      end

      describe "completing the subscription" do
        it "adds the user to the group when completing the transaction" do
          expect { post "/s/hooks.json" }.to change { user.groups.count }.by(1)

          expect(response.status).to eq 200
        end
      end

      it "does not create records or add the user to the group when payment_status is not paid" do
        unpaid_data = checkout_session_completed_data.deep_dup
        unpaid_data[:object][:payment_status] = "unpaid"
        event = { type: "checkout.session.completed", data: unpaid_data }
        ::Stripe::Webhook.stubs(:construct_event).returns(event)

        expect { post "/s/hooks.json" }.not_to change { user.groups.count }
        expect(response.status).to eq(200)
      end
    end

    describe "checkout.session.completed with unsigned metadata user id" do
      fab!(:other_user, :user)

      before do
        data = checkout_session_completed_data.deep_dup
        data[:object][:metadata] = { user_id: other_user.id }
        event = { type: "checkout.session.completed", data: data }

        ::Stripe::Checkout::Session
          .stubs(:list_line_items)
          .with(
            checkout_session_completed_data[:object][:id],
            { limit: 1 },
            DiscourseSubscriptions::Stripe.request_opts,
          )
          .returns(list_line_items_data)

        ::Stripe::Subscription.stubs(:update).returns({})
        ::Stripe::Webhook.stubs(:construct_event).returns(event)
      end

      it "ignores unsigned metadata" do
        expect { post "/s/hooks.json" }.to change { user.reload.groups.count }.by(1)

        aggregate_failures do
          expect(response.status).to eq(200)
          expect(group.reload.users).to contain_exactly(user)
          expect(DiscourseSubscriptions::Customer.order(:id).last.user_id).to eq(user.id)
        end
      end
    end

    describe "checkout.session.completed with conflicting email" do
      fab!(:other_user, :user)

      before do
        data = checkout_session_completed_data.deep_dup
        data[:object][:customer_email] = other_user.email
        event = { type: "checkout.session.completed", data: data }

        ::Stripe::Checkout::Session.expects(:list_line_items).never
        ::Stripe::Subscription.expects(:update).never
        ::Stripe::Webhook.stubs(:construct_event).returns(event)
      end

      it "rejects the mismatched checkout email" do
        expect { post "/s/hooks.json" }.not_to change { DiscourseSubscriptions::Customer.count }

        aggregate_failures do
          expect(response.status).to eq(422)
          expect(group.reload.users).to be_empty
        end
      end
    end

    describe "checkout.session.completed without customer and with conflicting email" do
      fab!(:other_user, :user)

      before do
        data = checkout_session_completed_data_one_off.deep_dup
        data[:object][:customer_email] = other_user.email
        event = { type: "checkout.session.completed", data: data }

        ::Stripe::Checkout::Session.expects(:list_line_items).never
        ::Stripe::Customer.expects(:create).never
        ::Stripe::Subscription.expects(:update).never
        ::Stripe::Webhook.stubs(:construct_event).returns(event)
      end

      it "rejects before creating a Stripe customer" do
        expect { post "/s/hooks.json" }.not_to change { DiscourseSubscriptions::Customer.count }

        aggregate_failures do
          expect(response.status).to eq(422)
          expect(group.reload.users).to be_empty
        end
      end
    end

    describe "checkout.session.completed without a trusted user reference" do
      before do
        data = checkout_session_completed_data.deep_dup
        data[:object].delete(:client_reference_id)
        event = { type: "checkout.session.completed", data: data }

        ::Stripe::Checkout::Session.expects(:list_line_items).never
        ::Stripe::Subscription.expects(:update).never
        ::Stripe::Webhook.stubs(:construct_event).returns(event)
      end

      it "does not bind by customer email" do
        expect { post "/s/hooks.json" }.not_to change { DiscourseSubscriptions::Customer.count }

        aggregate_failures do
          expect(response.status).to eq(422)
          expect(group.reload.users).to be_empty
        end
      end
    end

    describe "checkout.session.completed with an invalid user reference" do
      before do
        data = checkout_session_completed_data.deep_dup
        data[:object][:client_reference_id] = "tampered-reference"
        event = { type: "checkout.session.completed", data: data }

        ::Stripe::Checkout::Session.expects(:list_line_items).never
        ::Stripe::Subscription.expects(:update).never
        ::Stripe::Webhook.stubs(:construct_event).returns(event)
      end

      it "does not fall back to customer email" do
        expect { post "/s/hooks.json" }.not_to change { DiscourseSubscriptions::Customer.count }

        aggregate_failures do
          expect(response.status).to eq(422)
          expect(group.reload.users).to be_empty
        end
      end
    end

    describe "checkout.session.completed without customer email" do
      before do
        data = checkout_session_completed_data.deep_dup
        data[:object][:customer_email] = nil
        event = { type: "checkout.session.completed", data: data }

        ::Stripe::Checkout::Session.expects(:list_line_items).never
        ::Stripe::Subscription.expects(:update).never
        ::Stripe::Webhook.stubs(:construct_event).returns(event)
      end

      it "keeps rejecting the event" do
        expect { post "/s/hooks.json" }.not_to change { DiscourseSubscriptions::Customer.count }

        aggregate_failures do
          expect(response.status).to eq(422)
          expect(group.reload.users).to be_empty
        end
      end
    end

    describe "checkout.session.completed with bad data" do
      before do
        data = checkout_session_completed_bad_data.deep_dup
        data[:object][:client_reference_id] = client_reference_id
        event = { type: "checkout.session.completed", data: data }

        ::Stripe::Checkout::Session.expects(:list_line_items).never
        ::Stripe::Customer.expects(:create).never
        ::Stripe::Subscription.expects(:update).never
        ::Stripe::Webhook.stubs(:construct_event).returns(event)
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
          .with(
            checkout_session_completed_data[:object][:id],
            { limit: 1 },
            DiscourseSubscriptions::Stripe.request_opts,
          )
          .returns(list_line_items_data)

        ::Stripe::Webhook.stubs(:construct_event).returns(event)
        ::Stripe::Customer
          .stubs(:create)
          .with({ email: user.email }, DiscourseSubscriptions::Stripe.request_opts)
          .returns(id: "cus_1234")
      end

      it "is returns 200" do
        expect { post "/s/hooks.json" }.to change { user.groups.count }.by(1)
        expect(response.status).to eq 200
      end
    end

    describe "checkout.session.completed with anonymous user" do
      before do
        data = checkout_session_completed_bad_data.deep_dup
        data[:object][:customer_email] = "anonymous@example.com"
        data[:object][:client_reference_id] = client_reference_id
        event = { type: "checkout.session.completed", data: data }

        ::Stripe::Checkout::Session.expects(:list_line_items).never
        ::Stripe::Customer.expects(:create).never
        ::Stripe::Subscription.expects(:update).never
        ::Stripe::Webhook.stubs(:construct_event).returns(event)
      end

      it "is returns 422" do
        post "/s/hooks.json"
        expect(response.status).to eq 422
      end
    end

    describe "checkout.session.completed with no customer email or customer" do
      before do
        data = checkout_session_completed_bad_data.deep_dup
        data[:object][:customer_email] = nil
        data[:object][:client_reference_id] = client_reference_id
        event = { type: "checkout.session.completed", data: data }

        ::Stripe::Checkout::Session.expects(:list_line_items).never
        ::Stripe::Customer.expects(:create).never
        ::Stripe::Subscription.expects(:update).never
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

      it "is successful" do
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

    describe "checkout.session.async_payment_succeeded" do
      before do
        event = {
          type: "checkout.session.async_payment_succeeded",
          data: checkout_session_completed_data,
        }
        ::Stripe::Webhook.stubs(:construct_event).returns(event)
        ::Stripe::Checkout::Session
          .stubs(:list_line_items)
          .with(
            checkout_session_completed_data[:object][:id],
            { limit: 1 },
            DiscourseSubscriptions::Stripe.request_opts,
          )
          .returns(list_line_items_data)
        ::Stripe::Subscription
          .stubs(:update)
          .with(
            checkout_session_completed_data[:object][:subscription],
            { metadata: { user_id: user.id, username: user.username } },
            DiscourseSubscriptions::Stripe.request_opts,
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
      end

      it "creates customer and subscription records and adds the user to the group" do
        post "/s/hooks.json"

        expect(response.status).to eq(200)
        expect(user.groups).to include(group)

        expect(
          DiscourseSubscriptions::Customer.exists?(
            user_id: user.id,
            customer_id: customer.customer_id,
            product_id: "prod_PhB6IpGhEX14Hi",
          ),
        ).to eq(true)
        expect(
          DiscourseSubscriptions::Subscription.exists?(
            customer_id: DiscourseSubscriptions::Customer.last.id,
            external_id: "sub_1P9b7iEYXaQnncSh3H3G9d2Y",
          ),
        ).to eq(true)
      end
    end
  end
end
