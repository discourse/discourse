# frozen_string_literal: true

RSpec.describe DiscourseSubscriptions::HooksController, :setup_stripe_mock do
  before do
    setup_discourse_subscriptions
    SiteSetting.discourse_subscriptions_webhook_secret = "zascharoo"
  end

  it "rejects webhooks when webhook secret is blank" do
    SiteSetting.discourse_subscriptions_webhook_secret = ""
    post "/s/hooks.json", params: "{}", headers: { HTTP_STRIPE_SIGNATURE: "t=1,v1=abc" }
    expect(response.status).to eq(403)
  end

  it "constructs a webhook event" do
    payload = "we-want-a-shrubbery"
    headers = { HTTP_STRIPE_SIGNATURE: "stripe-webhook-signature" }

    ::Stripe::Webhook
      .expects(:construct_event)
      .with("we-want-a-shrubbery", "stripe-webhook-signature", "zascharoo")
      .returns(type: "something")

    post "/s/hooks.json", params: payload, headers: headers

    expect(response.status).to eq(200)
  end

  describe "event types" do
    let(:user) { Fabricate(:user) }
    let(:group) { Fabricate(:group, name: "subscribers-group") }

    describe "checkout.session.completed" do
      it "adds the user to the group when completing the transaction" do
        group

        product = ::Stripe::Product.create(name: "Hook Product", type: "service")
        price =
          ::Stripe::Price.create(
            product: product.id,
            unit_amount: 1000,
            currency: "usd",
            recurring: {
              interval: "month",
            },
            metadata: {
              group_name: group.name,
              trial_period_days: "0",
            },
          )
        customer =
          ::Stripe::Customer.create(email: user.email, source: StripeMock.generate_card_token)
        subscription =
          ::Stripe::Subscription.create(customer: customer.id, items: [{ price: price.id }])

        checkout_session_id = "cs_test_#{SecureRandom.hex(8)}"

        ::Stripe::Checkout::Session.stubs(:list_line_items).returns(
          Stripe::ListObject.construct_from(
            data: [
              {
                price: {
                  product: product.id,
                  metadata: {
                    group_name: group.name,
                    trial_period_days: "0",
                  },
                },
              },
            ],
          ),
        )

        event = {
          type: "checkout.session.completed",
          data: {
            object: {
              id: checkout_session_id,
              object: "checkout.session",
              customer: customer.id,
              customer_email: user.email,
              invoice: subscription.latest_invoice,
              metadata: {
              },
              mode: "subscription",
              payment_status: "paid",
              status: "complete",
              subscription: subscription.id,
              success_url: "http://localhost:4200/success",
            },
          },
        }

        ::Stripe::Webhook.stubs(:construct_event).returns(event)

        expect { post "/s/hooks.json" }.to change { user.groups.count }.by(1)
        expect(response.status).to eq(200)
      end
    end

    describe "checkout.session.completed with bad data" do
      it "returns 422 when customer_email is nil" do
        event = {
          type: "checkout.session.completed",
          data: {
            object: {
              id: "cs_test_fake",
              object: "checkout.session",
              customer: nil,
              customer_email: nil,
              invoice: nil,
              metadata: {
              },
              mode: "subscription",
              payment_status: "paid",
              status: "complete",
              subscription: nil,
              success_url: "http://localhost:4200/success",
            },
          },
        }

        ::Stripe::Webhook.stubs(:construct_event).returns(event)

        post "/s/hooks.json"
        expect(response.status).to eq(422)
      end
    end

    describe "checkout.session.completed for one-off purchase" do
      it "adds user to group for one-off purchase" do
        group

        product = ::Stripe::Product.create(name: "One Off Hook Product", type: "service")
        price =
          ::Stripe::Price.create(
            product: product.id,
            unit_amount: 2000,
            currency: "usd",
            metadata: {
              group_name: group.name,
              trial_period_days: "0",
            },
          )

        checkout_session_id = "cs_test_#{SecureRandom.hex(8)}"

        ::Stripe::Checkout::Session.stubs(:list_line_items).returns(
          Stripe::ListObject.construct_from(
            data: [
              {
                price: {
                  product: product.id,
                  metadata: {
                    group_name: group.name,
                    trial_period_days: "0",
                  },
                },
              },
            ],
          ),
        )

        event = {
          type: "checkout.session.completed",
          data: {
            object: {
              id: checkout_session_id,
              object: "checkout.session",
              customer: nil,
              customer_email: user.email,
              invoice: nil,
              metadata: {
              },
              mode: "payment",
              payment_intent: "pi_fake",
              payment_status: "paid",
              status: "complete",
              subscription: nil,
              success_url: "http://localhost:4200/success",
            },
          },
        }

        ::Stripe::Webhook.stubs(:construct_event).returns(event)

        expect { post "/s/hooks.json" }.to change { user.groups.count }.by(1)
        expect(response.status).to eq(200)
      end
    end

    describe "checkout.session.completed with anonymous user" do
      it "returns 422" do
        ::Stripe::Customer.stubs(:create).returns(id: "cus_fake")

        event = {
          type: "checkout.session.completed",
          data: {
            object: {
              id: "cs_test_fake",
              object: "checkout.session",
              customer: nil,
              customer_email: "anonymous@example.com",
              invoice: nil,
              metadata: {
              },
              mode: "subscription",
              payment_status: "paid",
              status: "complete",
              subscription: nil,
              success_url: "http://localhost:4200/success",
            },
          },
        }

        ::Stripe::Webhook.stubs(:construct_event).returns(event)

        post "/s/hooks.json"
        expect(response.status).to eq(422)
      end
    end

    describe "customer.subscription.updated" do
      let(:customer) do
        Fabricate(:customer, customer_id: "c_575768", product_id: "p_8654", user_id: user.id)
      end
      let!(:subscription) do
        Fabricate(:subscription, external_id: "sub_12345", customer_id: customer.id, status: nil)
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

      before do
        group
        ::Stripe::Webhook.stubs(:construct_event).returns(
          type: "customer.subscription.updated",
          data: event_data,
        )
      end

      it "is successful" do
        post "/s/hooks.json"
        expect(response.status).to eq(200)
      end

      it "does not add the user to the group when status stays incomplete" do
        event_data[:object][:status] = "incomplete"
        event_data[:previous_attributes] = { status: "incomplete" }

        expect { post "/s/hooks.json" }.not_to change { user.groups.count }
        expect(response.status).to eq(200)
      end

      it "does not add the user to the group when status is incomplete from other" do
        event_data[:object][:status] = "incomplete"
        event_data[:previous_attributes] = { status: "something-else" }

        expect { post "/s/hooks.json" }.not_to change { user.groups.count }
        expect(response.status).to eq(200)
      end

      it "adds the user to the group when completing the transaction" do
        event_data[:object][:status] = "complete"
        event_data[:previous_attributes] = { status: "incomplete" }

        expect { post "/s/hooks.json" }.to change { user.groups.count }.by(1)
        expect(response.status).to eq(200)
      end

      it "adds the user to the group when status is active" do
        event_data[:object][:status] = "active"

        expect { post "/s/hooks.json" }.to change { user.groups.count }.by(1)
        expect(response.status).to eq(200)
      end
    end

    describe "customer.subscription.deleted" do
      let(:customer) do
        Fabricate(:customer, customer_id: "c_575768", product_id: "p_8654", user_id: user.id)
      end
      let!(:subscription) do
        Fabricate(:subscription, external_id: "sub_12345", customer_id: customer.id, status: nil)
      end

      before do
        group.add(user)

        event = {
          type: "customer.subscription.deleted",
          data: {
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
          },
        }

        ::Stripe::Webhook.stubs(:construct_event).returns(event)
      end

      it "marks the subscription as canceled" do
        expect { post "/s/hooks.json" }.to change {
          DiscourseSubscriptions::Subscription.where(status: "canceled").count
        }.by(+1)

        expect(response.status).to eq(200)
      end

      it "removes the user from the group" do
        expect { post "/s/hooks.json" }.to change { user.groups.count }.by(-1)
        expect(response.status).to eq(200)
      end
    end
  end
end
