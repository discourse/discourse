# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseSubscriptions::SubscribeController do
  let(:user) { Fabricate(:user) }
  let(:campaign_user) { Fabricate(:user) }

  before { SiteSetting.discourse_subscriptions_enabled = true }

  context "when showing products" do
    let(:product) do
      {
        id: "prodct_23456",
        name: "Very Special Product",
        metadata: {
          description:
            "Many people listened to my phone call with the Ukrainian President while it was being made",
          repurchaseable: false,
        },
        otherstuff: true,
      }
    end

    let(:prices) do
      {
        data: [
          {
            id: "plan_id123",
            unit_amount: 1220,
            currency: "aud",
            recurring: {
              interval: "year",
            },
            metadata: {
            },
          },
          {
            id: "plan_id234",
            unit_amount: 1399,
            currency: "usd",
            recurring: {
              interval: "year",
            },
            metadata: {
            },
          },
          {
            id: "plan_id678",
            unit_amount: 1000,
            currency: "aud",
            recurring: {
              interval: "week",
            },
            metadata: {
            },
          },
        ],
      }
    end

    let(:product_ids) { ["prodct_23456"] }

    before do
      sign_in(user)
      Fabricate(:product, external_id: "prodct_23456")
      SiteSetting.discourse_subscriptions_public_key = "public-key"
      SiteSetting.discourse_subscriptions_secret_key = "secret-key"
    end

    describe "#index" do
      let(:customer) do
        Fabricate(:customer, product_id: product[:id], user_id: user.id, customer_id: "x")
      end

      it "gets products" do
        ::Stripe::Product
          .expects(:list)
          .with({ ids: product_ids, active: true })
          .returns(data: [product])

        get "/s.json"

        expect(response.parsed_body).to eq(
          [
            {
              "id" => "prodct_23456",
              "name" => "Very Special Product",
              "description" =>
                PrettyText.cook(
                  "Many people listened to my phone call with the Ukrainian President while it was being made",
                ),
              "subscribed" => false,
              "repurchaseable" => false,
            },
          ],
        )
      end

      it "is subscribed" do
        Fabricate(:subscription, external_id: "sub_12345", customer_id: customer.id, status: nil)

        ::Stripe::Product
          .expects(:list)
          .with({ ids: product_ids, active: true })
          .returns(data: [product])

        get "/s.json"
        data = response.parsed_body
        expect(data.first["subscribed"]).to eq true
      end

      it "is not subscribed" do
        ::DiscourseSubscriptions::Customer.delete_all
        ::Stripe::Product
          .expects(:list)
          .with({ ids: product_ids, active: true })
          .returns(data: [product])

        get "/s.json"
        data = response.parsed_body
        expect(data.first["subscribed"]).to eq false
      end
    end

    describe "#get_contributors" do
      before do
        Fabricate(:product, external_id: "prod_campaign")
        Fabricate(:customer, product_id: "prodct_23456", user_id: user.id, customer_id: "x")
        Fabricate(
          :customer,
          product_id: "prod_campaign",
          user_id: campaign_user.id,
          customer_id: "y",
        )
      end
      context "when not showing contributors" do
        it "returns nothing if not set to show contributors" do
          SiteSetting.discourse_subscriptions_campaign_show_contributors = false
          get "/s/contributors.json"

          data = response.parsed_body
          expect(data).to be_empty
        end
      end

      context "when showing contributors" do
        before { SiteSetting.discourse_subscriptions_campaign_show_contributors = true }

        it "filters users by campaign product if set" do
          SiteSetting.discourse_subscriptions_campaign_product = "prod_campaign"

          get "/s/contributors.json"

          data = response.parsed_body
          expect(data.first["id"]).to eq campaign_user.id
          expect(data.length).to eq 1
        end

        it "shows all purchases if campaign product not set" do
          SiteSetting.discourse_subscriptions_campaign_product = nil

          get "/s/contributors.json"

          data = response.parsed_body
          expect(data.length).to eq 2
        end
      end
    end

    describe "#show" do
      it "retrieves the product" do
        ::Stripe::Product.expects(:retrieve).with("prod_walterwhite").returns(product)
        ::Stripe::Price
          .expects(:list)
          .with(active: true, product: "prod_walterwhite")
          .returns(prices)
        get "/s/prod_walterwhite.json"

        expect(response.parsed_body).to eq(
          {
            "product" => {
              "id" => "prodct_23456",
              "name" => "Very Special Product",
              "description" =>
                PrettyText.cook(
                  "Many people listened to my phone call with the Ukrainian President while it was being made",
                ),
              "subscribed" => false,
              "repurchaseable" => false,
            },
            "plans" => [
              {
                "currency" => "aud",
                "id" => "plan_id123",
                "recurring" => {
                  "interval" => "year",
                },
                "unit_amount" => 1220,
              },
              {
                "currency" => "usd",
                "id" => "plan_id234",
                "recurring" => {
                  "interval" => "year",
                },
                "unit_amount" => 1399,
              },
              {
                "currency" => "aud",
                "id" => "plan_id678",
                "recurring" => {
                  "interval" => "week",
                },
                "unit_amount" => 1000,
              },
            ],
          },
        )
      end
    end
  end

  context "when creating subscriptions" do
    context "when unauthenticated" do
      it "does not create a subscription" do
        ::Stripe::Customer.expects(:create).never
        ::Stripe::Price.expects(:retrieve).never
        ::Stripe::Subscription.expects(:create).never
        post "/s/create.json", params: { plan: "plan_1234", source: "tok_1234" }
      end
    end

    context "when authenticated" do
      before { sign_in(user) }

      describe "#create" do
        before { ::Stripe::Customer.expects(:create).returns(id: "cus_1234") }

        it "creates a subscription without automatic_tax param" do
          SiteSetting.discourse_subscriptions_enable_automatic_tax = false
          ::Stripe::Price.expects(:retrieve).returns(
            type: "recurring",
            product: "product_12345",
            metadata: {
              group_name: "awesome",
              trial_period_days: 0,
            },
          )

          expected_subscription_params = {
            customer: "cus_1234",
            items: [{ price: "plan_1234" }],
            metadata: {
              user_id: user.id,
              username: user.username_lower,
            },
            trial_period_days: 0,
            promotion_code: nil,
          }

          ::Stripe::Subscription
            .expects(:create)
            .with do |params|
              params == expected_subscription_params && !params.key?(:automatic_tax)
            end
            .returns(status: "active", customer: "cus_1234")

          expect {
            post "/s/create.json", params: { plan: "plan_1234", source: "tok_1234" }
          }.to change { DiscourseSubscriptions::Customer.count }
        end

        it "creates a subscription with automatic tax" do
          SiteSetting.discourse_subscriptions_enable_automatic_tax = true
          ::Stripe::Price.expects(:retrieve).returns(
            type: "recurring",
            product: "product_12345",
            metadata: {
              group_name: "awesome",
              trial_period_days: 0,
            },
          )

          expected_subscription_params = {
            customer: "cus_1234",
            items: [{ price: "plan_1234" }],
            metadata: {
              user_id: user.id,
              username: user.username_lower,
            },
            trial_period_days: 0,
            promotion_code: nil,
            automatic_tax: {
              enabled: true,
            },
          }

          ::Stripe::Subscription
            .expects(:create)
            .with(expected_subscription_params)
            .returns(status: "active", customer: "cus_1234")

          expect {
            post "/s/create.json", params: { plan: "plan_1234", source: "tok_1234" }
          }.to change { DiscourseSubscriptions::Customer.count }
        end

        it "returns 422 on a one time payment subscription error" do
          # It's possible that the invoice item doesn't get attached
          # to the invoice. This means the invoice is paid, but for $0.00 with
          # a pending invoice item.
          ::Stripe::Price.expects(:retrieve).returns(
            type: "one_time",
            product: "product_12345",
            metadata: {
              group_name: "awesome",
            },
          )

          ::Stripe::InvoiceItem.expects(:create)

          ::Stripe::Invoice.expects(:create).returns(status: "open", id: "in_123")

          ::Stripe::Invoice.expects(:finalize_invoice).returns(
            id: "in_123",
            status: "paid",
            payment_intent: "pi_123",
          )

          expect {
            post "/s/create.json", params: { plan: "plan_1234", source: "tok_1234" }
          }.not_to change { DiscourseSubscriptions::Customer.count }

          expect(response.status).to eq 422
        end

        it "creates a one time payment subscription without automatic tax" do
          SiteSetting.discourse_subscriptions_enable_automatic_tax = false
          ::Stripe::Price.expects(:retrieve).returns(
            type: "one_time",
            product: "product_12345",
            metadata: {
              group_name: "awesome",
            },
          )

          ::Stripe::InvoiceItem.expects(:create)

          expected_one_time_params = { customer: "cus_1234" }

          ::Stripe::Invoice
            .expects(:create)
            .with { |params| params == expected_one_time_params && !params.key?(:automatic_tax) }
            .returns(status: "open", id: "in_123")

          ::Stripe::Invoice.expects(:finalize_invoice).returns(
            id: "in_123",
            status: "open",
            payment_intent: "pi_123",
          )

          ::Stripe::Invoice.expects(:retrieve).returns(
            id: "in_123",
            status: "open",
            payment_intent: "pi_123",
          )

          ::Stripe::PaymentIntent.expects(:retrieve).returns(status: "successful")

          ::Stripe::Invoice.expects(:pay).returns(status: "paid", customer: "cus_1234")

          expect {
            post "/s/create.json", params: { plan: "plan_1234", source: "tok_1234" }
          }.to change { DiscourseSubscriptions::Customer.count }
        end

        it "creates a one time payment subscription" do
          SiteSetting.discourse_subscriptions_enable_automatic_tax = true
          ::Stripe::Price.expects(:retrieve).returns(
            type: "one_time",
            product: "product_12345",
            metadata: {
              group_name: "awesome",
            },
          )

          ::Stripe::InvoiceItem.expects(:create)

          expected_one_time_params = { customer: "cus_1234", automatic_tax: { enabled: true } }

          ::Stripe::Invoice
            .expects(:create)
            .with(expected_one_time_params)
            .returns(status: "open", id: "in_123")

          ::Stripe::Invoice.expects(:finalize_invoice).returns(
            id: "in_123",
            status: "open",
            payment_intent: "pi_123",
          )

          ::Stripe::Invoice.expects(:retrieve).returns(
            id: "in_123",
            status: "open",
            payment_intent: "pi_123",
          )

          ::Stripe::PaymentIntent.expects(:retrieve).returns(status: "successful")

          ::Stripe::Invoice.expects(:pay).returns(status: "paid", customer: "cus_1234")

          expect {
            post "/s/create.json", params: { plan: "plan_1234", source: "tok_1234" }
          }.to change { DiscourseSubscriptions::Customer.count }
        end

        it "creates a customer model" do
          ::Stripe::Price.expects(:retrieve).returns(type: "recurring", metadata: {}).twice
          ::Stripe::Subscription.expects(:create).returns(status: "active", customer: "cus_1234")

          expect {
            post "/s/create.json", params: { plan: "plan_1234", source: "tok_1234" }
          }.to change { DiscourseSubscriptions::Customer.count }

          ::Stripe::Customer.expects(:retrieve).with("cus_1234")

          expect {
            post "/s/create.json", params: { plan: "plan_5678", source: "tok_5678" }
          }.not_to change { DiscourseSubscriptions::Customer.count }
        end

        context "with customer name & address" do
          it "creates a customer & subscription when a customer address is provided" do
            ::Stripe::Price.expects(:retrieve).returns(type: "recurring", metadata: {})
            ::Stripe::Subscription.expects(:create).returns(status: "active", customer: "cus_1234")
            expect {
              post "/s/create.json",
                   params: {
                     plan: "plan_1234",
                     source: "tok_1234",
                     cardholder_name: "A. Customer",
                     cardholder_address: {
                       line1: "123 Main Street",
                       city: "Anywhere",
                       state: "VT",
                       country: "US",
                       postal_code: "12345",
                     },
                   }
            }.to change { DiscourseSubscriptions::Customer.count }
          end
        end

        context "with promo code" do
          context "with invalid code" do
            it "prevents use of invalid coupon codes" do
              ::Stripe::Price.expects(:retrieve).returns(
                type: "recurring",
                product: "product_12345",
                metadata: {
                  group_name: "awesome",
                  trial_period_days: 0,
                },
              )

              ::Stripe::PromotionCode.expects(:list).with({ code: "invalid" }).returns(data: [])

              post "/s/create.json",
                   params: {
                     plan: "plan_1234",
                     source: "tok_1234",
                     promo: "invalid",
                   }

              data = response.parsed_body
              expect(data["errors"]).not_to be_blank
            end
          end

          context "with valid code" do
            before do
              ::Stripe::PromotionCode
                .expects(:list)
                .with({ code: "123" })
                .returns(data: [{ id: "promo123", coupon: { id: "c123" } }])
            end

            it "applies promo code to recurring subscription" do
              ::Stripe::Price.expects(:retrieve).returns(
                type: "recurring",
                product: "product_12345",
                metadata: {
                  group_name: "awesome",
                  trial_period_days: 0,
                },
              )

              expected_subscription_params = {
                customer: "cus_1234",
                items: [price: "plan_1234"],
                metadata: {
                  user_id: user.id,
                  username: user.username_lower,
                },
                trial_period_days: 0,
                promotion_code: "promo123",
              }

              ::Stripe::Subscription
                .expects(:create)
                .with(expected_subscription_params)
                .returns(status: "active", customer: "cus_1234")

              expect {
                post "/s/create.json",
                     params: {
                       plan: "plan_1234",
                       source: "tok_1234",
                       promo: "123",
                     }
              }.to change { DiscourseSubscriptions::Customer.count }
            end

            it "applies promo code to one time purchase" do
              ::Stripe::Price.expects(:retrieve).returns(
                type: "one_time",
                product: "product_12345",
                metadata: {
                  group_name: "awesome",
                },
              )

              ::Stripe::Invoice.expects(:create).returns(status: "open", id: "in_123")

              ::Stripe::InvoiceItem.expects(:create).with(
                customer: "cus_1234",
                price: "plan_1234",
                discounts: [{ coupon: "c123" }],
                invoice: "in_123",
              )

              ::Stripe::Invoice.expects(:finalize_invoice).returns(
                id: "in_123",
                status: "open",
                payment_intent: "pi_123",
              )

              ::Stripe::Invoice.expects(:retrieve).returns(
                id: "in_123",
                status: "open",
                payment_intent: "pi_123",
              )

              ::Stripe::PaymentIntent.expects(:retrieve).returns(status: "successful")

              ::Stripe::Invoice.expects(:pay).returns(status: "paid", customer: "cus_1234")

              expect {
                post "/s/create.json",
                     params: {
                       plan: "plan_1234",
                       source: "tok_1234",
                       promo: "123",
                     }
              }.to change { DiscourseSubscriptions::Customer.count }
            end
          end
        end
      end

      describe "#finalize strong customer authenticated transaction" do
        context "with subscription" do
          it "finalizes the subscription" do
            ::Stripe::Price.expects(:retrieve).returns(
              id: "plan_1234",
              product: "prod_1234",
              metadata: {
              },
            )
            ::Stripe::Subscription.expects(:retrieve).returns(
              id: "sub_123",
              customer: "cus_1234",
              status: "active",
            )

            expect {
              post "/s/finalize.json", params: { plan: "plan_1234", transaction: "sub_1234" }
            }.to change { DiscourseSubscriptions::Customer.count }
          end
        end

        context "with one-time payment" do
          it "finalizes the one-time payment" do
            ::Stripe::Price.expects(:retrieve).returns(
              id: "plan_1234",
              product: "prod_1234",
              metadata: {
              },
            )
            ::Stripe::Invoice.expects(:retrieve).returns(
              id: "in_123",
              customer: "cus_1234",
              status: "paid",
            )

            expect {
              post "/s/finalize.json", params: { plan: "plan_1234", transaction: "in_1234" }
            }.to change { DiscourseSubscriptions::Customer.count }
          end
        end
      end

      describe "user groups" do
        let(:group_name) { "group-123" }
        let(:group) { Fabricate(:group, name: group_name) }

        context "with unauthorized group" do
          before do
            ::Stripe::Customer.expects(:create).returns(id: "cus_1234")
            ::Stripe::Subscription.expects(:create).returns(status: "active")
          end

          it "does not add the user to the admins group" do
            ::Stripe::Price.expects(:retrieve).returns(
              type: "recurring",
              metadata: {
                group_name: "admins",
              },
            )
            post "/s/create.json", params: { plan: "plan_1234", source: "tok_1234" }
            expect(user.admin).to eq false
          end

          it "does not add the user to other group" do
            ::Stripe::Price.expects(:retrieve).returns(
              type: "recurring",
              metadata: {
                group_name: "other",
              },
            )
            post "/s/create.json", params: { plan: "plan_1234", source: "tok_1234" }
            expect(user.groups).to be_empty
          end
        end

        context "when plan has group in metadata" do
          before do
            ::Stripe::Customer.expects(:create).returns(id: "cus_1234")
            ::Stripe::Price.expects(:retrieve).returns(
              type: "recurring",
              metadata: {
                group_name: group_name,
              },
            )
          end

          it "does not add the user to the group when subscription fails" do
            ::Stripe::Subscription.expects(:create).returns(status: "failed")

            expect {
              post "/s/create.json", params: { plan: "plan_1234", source: "tok_1234" }
            }.not_to change { group.users.count }

            expect(user.groups).to be_empty
          end

          it "adds the user to the group when the subscription is active" do
            ::Stripe::Subscription.expects(:create).returns(status: "active")

            expect {
              post "/s/create.json", params: { plan: "plan_1234", source: "tok_1234" }
            }.to change { group.users.count }

            expect(user.groups).not_to be_empty
          end

          it "adds the user to the group when the subscription is trialing" do
            ::Stripe::Subscription.expects(:create).returns(status: "trialing")

            expect {
              post "/s/create.json", params: { plan: "plan_1234", source: "tok_1234" }
            }.to change { group.users.count }

            expect(user.groups).not_to be_empty
          end
        end
      end
    end
  end
end
