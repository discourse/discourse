# frozen_string_literal: true

RSpec.describe DiscourseSubscriptions::SubscribeController do
  let(:user) { Fabricate(:user) }
  let(:campaign_user) { Fabricate(:user) }

  before do
    SiteSetting.discourse_subscriptions_enabled = true
    SiteSetting.discourse_subscriptions_secret_key = "secret-key"
  end

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
    end

    describe "#index" do
      let(:customer) do
        Fabricate(:customer, product_id: product[:id], user_id: user.id, customer_id: "x")
      end

      it "gets products" do
        ::Stripe::ProductService
          .any_instance
          .expects(:list)
          .with({ ids: product_ids, active: true, limit: 100 })
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

        ::Stripe::ProductService
          .any_instance
          .expects(:list)
          .with({ ids: product_ids, active: true, limit: 100 })
          .returns(data: [product])

        get "/s.json"
        data = response.parsed_body
        expect(data.first["subscribed"]).to eq true
      end

      it "is not subscribed" do
        DiscourseSubscriptions::Customer.delete_all
        ::Stripe::ProductService
          .any_instance
          .expects(:list)
          .with({ ids: product_ids, active: true, limit: 100 })
          .returns(data: [product])

        get "/s.json"
        data = response.parsed_body
        expect(data.first["subscribed"]).to eq false
      end
    end

    describe "#get_contributors" do
      before do
        Fabricate(:product, external_id: "prod_campaign")
        user.user_stat.update!(post_count: 1)
        campaign_user.user_stat.update!(post_count: 1)
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
          SiteSetting.discourse_subscriptions_campaign_product = ""

          get "/s/contributors.json"

          data = response.parsed_body
          expect(data.length).to eq 2
        end
      end
    end

    describe "#show" do
      it "retrieves the product" do
        Fabricate(:product, external_id: "prod_walterwhite")

        ::Stripe::ProductService
          .any_instance
          .expects(:retrieve)
          .with("prod_walterwhite")
          .returns(product)
        ::Stripe::PriceService
          .any_instance
          .expects(:list)
          .with({ active: true, product: "prod_walterwhite" })
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

      it "returns 404 for a product outside the allowlist" do
        ::Stripe::ProductService.any_instance.expects(:retrieve).never
        ::Stripe::PriceService.any_instance.expects(:list).never

        get "/s/prod_hidden.json"

        expect(response.status).to eq(404)
      end
    end
  end

  describe "#contributors" do
    fab!(:contributor, :user)
    fab!(:hidden_contributor, :user)

    before do
      SiteSetting.discourse_subscriptions_campaign_show_contributors = true
      SiteSetting.discourse_subscriptions_campaign_product = ""
      SiteSetting.hide_user_profiles_from_public = false
      SiteSetting.allow_users_to_hide_profile = true
      contributor.user_stat.update!(post_count: 1)
      hidden_contributor.user_stat.update!(post_count: 1)
      hidden_contributor.user_option.update!(hide_profile: true)
      Fabricate(:customer, product_id: "prodct_23456", user_id: contributor.id, customer_id: "x")
      Fabricate(
        :customer,
        product_id: "prod_campaign",
        user_id: hidden_contributor.id,
        customer_id: "y",
      )
    end

    it "enforces profile visibility for anonymous contributors" do
      get "/s/contributors.json"

      expect(response).to have_http_status(:ok)
      visible_contributor_ids = response.parsed_body.map { |serialized_user| serialized_user["id"] }

      SiteSetting.hide_user_profiles_from_public = true

      get "/s/contributors.json"

      expect(visible_contributor_ids).to contain_exactly(contributor.id)
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to include("error_type" => "invalid_access")
    end
  end

  context "when creating subscriptions" do
    context "when unauthenticated" do
      it "does not create a subscription" do
        ::Stripe::CustomerService.any_instance.expects(:create).never
        ::Stripe::PriceService.any_instance.expects(:retrieve).never
        ::Stripe::SubscriptionService.any_instance.expects(:create).never
        post "/s/create.json", params: { plan: "plan_1234", source: "tok_1234" }
      end
    end

    context "when authenticated" do
      fab!(:published_product) { Fabricate(:product, external_id: "product_12345") }

      before { sign_in(user) }

      describe "#create" do
        before do
          ::Stripe::CustomerService
            .any_instance
            .stubs(:create)
            .with(anything)
            .returns(id: "cus_1234")
        end

        it "creates a subscription without automatic_tax param" do
          SiteSetting.discourse_subscriptions_enable_automatic_tax = false
          ::Stripe::PriceService
            .any_instance
            .expects(:retrieve)
            .with(anything)
            .returns(
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

          ::Stripe::SubscriptionService
            .any_instance
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
          ::Stripe::PriceService
            .any_instance
            .expects(:retrieve)
            .with(anything)
            .returns(
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

          ::Stripe::SubscriptionService
            .any_instance
            .expects(:create)
            .with(expected_subscription_params)
            .returns(status: "active", customer: "cus_1234")

          expect {
            post "/s/create.json", params: { plan: "plan_1234", source: "tok_1234" }
          }.to change { DiscourseSubscriptions::Customer.count }
        end

        it "rejects a plan outside the allowlist" do
          ::Stripe::PriceService
            .any_instance
            .expects(:retrieve)
            .with("price_hidden")
            .returns(
              type: "recurring",
              product: "prod_hidden",
              metadata: {
                group_name: "awesome",
                trial_period_days: 0,
              },
            )
          ::Stripe::CustomerService.any_instance.expects(:create).never
          ::Stripe::SubscriptionService.any_instance.expects(:create).never

          expect {
            post "/s/create.json", params: { plan: "price_hidden", source: "tok_1234" }
          }.not_to change { DiscourseSubscriptions::Customer.count }

          expect(response.status).to eq(404)
        end

        it "returns 422 on a one time payment subscription error" do
          # It's possible that the invoice item doesn't get attached
          # to the invoice. This means the invoice is paid, but for $0.00 with
          # a pending invoice item.
          ::Stripe::PriceService
            .any_instance
            .expects(:retrieve)
            .with(anything)
            .returns(
              type: "one_time",
              product: "product_12345",
              metadata: {
                group_name: "awesome",
              },
            )

          ::Stripe::InvoiceItemService.any_instance.expects(:create).with(anything)

          ::Stripe::InvoiceService
            .any_instance
            .expects(:create)
            .with(anything)
            .returns(status: "open", id: "in_123")

          ::Stripe::InvoiceService
            .any_instance
            .expects(:finalize_invoice)
            .with(anything, anything)
            .returns(id: "in_123", status: "paid", payment_intent: "pi_123")

          expect {
            post "/s/create.json", params: { plan: "plan_1234", source: "tok_1234" }
          }.not_to change { DiscourseSubscriptions::Customer.count }

          expect(response.status).to eq 422
        end

        it "creates a one time payment subscription without automatic tax" do
          SiteSetting.discourse_subscriptions_enable_automatic_tax = false
          ::Stripe::PriceService
            .any_instance
            .expects(:retrieve)
            .with(anything)
            .returns(
              type: "one_time",
              product: "product_12345",
              metadata: {
                group_name: "awesome",
              },
            )

          ::Stripe::InvoiceItemService.any_instance.expects(:create).with(anything)

          expected_one_time_params = { customer: "cus_1234" }

          ::Stripe::InvoiceService
            .any_instance
            .expects(:create)
            .with { |params| params == expected_one_time_params && !params.key?(:automatic_tax) }
            .returns(status: "open", id: "in_123")

          ::Stripe::InvoiceService
            .any_instance
            .expects(:finalize_invoice)
            .with(anything, anything)
            .returns(id: "in_123", status: "open", payment_intent: "pi_123")

          ::Stripe::InvoiceService
            .any_instance
            .expects(:retrieve)
            .with(anything)
            .returns(id: "in_123", status: "open", payment_intent: "pi_123")

          ::Stripe::PaymentIntentService
            .any_instance
            .expects(:retrieve)
            .with(anything)
            .returns(status: "successful")

          ::Stripe::InvoiceService
            .any_instance
            .expects(:pay)
            .with(anything, anything)
            .returns(status: "paid", customer: "cus_1234")

          expect {
            post "/s/create.json", params: { plan: "plan_1234", source: "tok_1234" }
          }.to change { DiscourseSubscriptions::Customer.count }
        end

        it "creates a one time payment subscription" do
          SiteSetting.discourse_subscriptions_enable_automatic_tax = true
          ::Stripe::PriceService
            .any_instance
            .expects(:retrieve)
            .with(anything)
            .returns(
              type: "one_time",
              product: "product_12345",
              metadata: {
                group_name: "awesome",
              },
            )

          ::Stripe::InvoiceItemService.any_instance.expects(:create).with(anything)

          expected_one_time_params = { customer: "cus_1234", automatic_tax: { enabled: true } }

          ::Stripe::InvoiceService
            .any_instance
            .expects(:create)
            .with(expected_one_time_params)
            .returns(status: "open", id: "in_123")

          ::Stripe::InvoiceService
            .any_instance
            .expects(:finalize_invoice)
            .with(anything, anything)
            .returns(id: "in_123", status: "open", payment_intent: "pi_123")

          ::Stripe::InvoiceService
            .any_instance
            .expects(:retrieve)
            .with(anything)
            .returns(id: "in_123", status: "open", payment_intent: "pi_123")

          ::Stripe::PaymentIntentService
            .any_instance
            .expects(:retrieve)
            .with(anything)
            .returns(status: "successful")

          ::Stripe::InvoiceService
            .any_instance
            .expects(:pay)
            .with(anything, anything)
            .returns(status: "paid", customer: "cus_1234")

          expect {
            post "/s/create.json", params: { plan: "plan_1234", source: "tok_1234" }
          }.to change { DiscourseSubscriptions::Customer.count }
        end

        it "creates a customer model" do
          ::Stripe::PriceService
            .any_instance
            .expects(:retrieve)
            .with(anything)
            .returns(type: "recurring", product: "product_12345", metadata: {})
            .twice
          ::Stripe::SubscriptionService
            .any_instance
            .expects(:create)
            .with(anything)
            .returns(status: "active", customer: "cus_1234")

          expect {
            post "/s/create.json", params: { plan: "plan_1234", source: "tok_1234" }
          }.to change { DiscourseSubscriptions::Customer.count }

          ::Stripe::CustomerService.any_instance.expects(:retrieve).with("cus_1234")

          expect {
            post "/s/create.json", params: { plan: "plan_5678", source: "tok_5678" }
          }.not_to change { DiscourseSubscriptions::Customer.count }
        end

        context "with customer name & address" do
          it "creates a customer & subscription when a customer address is provided" do
            ::Stripe::PriceService
              .any_instance
              .expects(:retrieve)
              .with(anything)
              .returns(type: "recurring", product: "product_12345", metadata: {})
            ::Stripe::SubscriptionService
              .any_instance
              .expects(:create)
              .with(anything)
              .returns(status: "active", customer: "cus_1234")
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
              ::Stripe::PriceService
                .any_instance
                .expects(:retrieve)
                .with(anything)
                .returns(
                  type: "recurring",
                  product: "product_12345",
                  metadata: {
                    group_name: "awesome",
                    trial_period_days: 0,
                  },
                )

              ::Stripe::PromotionCodeService
                .any_instance
                .expects(:list)
                .with({ code: "invalid" })
                .returns(data: [])

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
              ::Stripe::PromotionCodeService
                .any_instance
                .expects(:list)
                .with({ code: "123" })
                .returns(data: [{ id: "promo123", coupon: { id: "c123" } }])
            end

            it "applies promo code to recurring subscription" do
              ::Stripe::PriceService
                .any_instance
                .expects(:retrieve)
                .with(anything)
                .returns(
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

              ::Stripe::SubscriptionService
                .any_instance
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
              ::Stripe::PriceService
                .any_instance
                .expects(:retrieve)
                .with(anything)
                .returns(
                  type: "one_time",
                  product: "product_12345",
                  metadata: {
                    group_name: "awesome",
                  },
                )

              ::Stripe::InvoiceService
                .any_instance
                .expects(:create)
                .with(anything)
                .returns(status: "open", id: "in_123")

              ::Stripe::InvoiceItemService
                .any_instance
                .expects(:create)
                .with(
                  {
                    customer: "cus_1234",
                    price: "plan_1234",
                    discounts: [{ coupon: "c123" }],
                    invoice: "in_123",
                  },
                )

              ::Stripe::InvoiceService
                .any_instance
                .expects(:finalize_invoice)
                .with(anything, anything)
                .returns(id: "in_123", status: "open", payment_intent: "pi_123")

              ::Stripe::InvoiceService
                .any_instance
                .expects(:retrieve)
                .with(anything)
                .returns(id: "in_123", status: "open", payment_intent: "pi_123")

              ::Stripe::PaymentIntentService
                .any_instance
                .expects(:retrieve)
                .with(anything)
                .returns(status: "successful")

              ::Stripe::InvoiceService
                .any_instance
                .expects(:pay)
                .with(anything, anything)
                .returns(status: "paid", customer: "cus_1234")

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
            server_session["pending_subscription"] = {
              transaction_id: "sub_1234",
              plan_id: "plan_1234",
            }
            ::Stripe::PriceService
              .any_instance
              .expects(:retrieve)
              .with(anything)
              .returns(id: "plan_1234", product: "product_12345", metadata: {})
            ::Stripe::SubscriptionService
              .any_instance
              .expects(:retrieve)
              .with(anything)
              .returns(id: "sub_123", customer: "cus_1234", status: "active")

            expect { post "/s/finalize.json" }.to change { DiscourseSubscriptions::Customer.count }
          end
        end

        context "with one-time payment" do
          it "finalizes the one-time payment" do
            server_session["pending_subscription"] = {
              transaction_id: "in_1234",
              plan_id: "plan_1234",
            }
            ::Stripe::PriceService
              .any_instance
              .expects(:retrieve)
              .with(anything)
              .returns(id: "plan_1234", product: "product_12345", metadata: {})
            ::Stripe::InvoiceService
              .any_instance
              .expects(:retrieve)
              .with(anything)
              .returns(id: "in_123", customer: "cus_1234", status: "paid")

            expect { post "/s/finalize.json" }.to change { DiscourseSubscriptions::Customer.count }
          end
        end

        it "returns 403 with no pending server session" do
          post "/s/finalize.json"
          expect(response.status).to eq(403)
        end

        it "prevents replay by rejecting a second finalize" do
          server_session["pending_subscription"] = {
            transaction_id: "sub_123",
            plan_id: "plan_1234",
          }
          ::Stripe::PriceService
            .any_instance
            .expects(:retrieve)
            .with(anything)
            .returns(id: "plan_1234", product: "product_12345", metadata: {})
          ::Stripe::SubscriptionService
            .any_instance
            .expects(:retrieve)
            .with(anything)
            .returns(id: "sub_123", customer: "cus_1234", status: "active")

          post "/s/finalize.json"
          expect(response.status).to eq(200)

          post "/s/finalize.json"
          expect(response.status).to eq(403)
        end

        it "rejects a pending plan outside the allowlist" do
          server_session["pending_subscription"] = {
            transaction_id: "sub_123",
            plan_id: "price_hidden",
          }
          ::Stripe::PriceService
            .any_instance
            .expects(:retrieve)
            .with("price_hidden")
            .returns(id: "price_hidden", product: "prod_hidden", metadata: {})
          ::Stripe::SubscriptionService.any_instance.expects(:retrieve).never

          expect { post "/s/finalize.json" }.not_to change {
            DiscourseSubscriptions::Customer.count
          }

          expect(response.status).to eq(404)
        end
      end

      describe "user groups" do
        let(:group_name) { "group-123" }
        let(:group) { Fabricate(:group, name: group_name) }

        context "with unauthorized group" do
          before do
            ::Stripe::CustomerService
              .any_instance
              .expects(:create)
              .with(anything)
              .returns(id: "cus_1234")
            ::Stripe::SubscriptionService
              .any_instance
              .expects(:create)
              .with(anything)
              .returns(status: "active")
          end

          it "does not add the user to the admins group" do
            ::Stripe::PriceService
              .any_instance
              .expects(:retrieve)
              .with(anything)
              .returns(
                type: "recurring",
                product: "product_12345",
                metadata: {
                  group_name: "admins",
                },
              )
            post "/s/create.json", params: { plan: "plan_1234", source: "tok_1234" }
            expect(user.admin).to eq false
          end

          it "does not add the user to other group" do
            ::Stripe::PriceService
              .any_instance
              .expects(:retrieve)
              .with(anything)
              .returns(
                type: "recurring",
                product: "product_12345",
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
            ::Stripe::CustomerService
              .any_instance
              .expects(:create)
              .with(anything)
              .returns(id: "cus_1234")
            ::Stripe::PriceService
              .any_instance
              .expects(:retrieve)
              .with(anything)
              .returns(
                type: "recurring",
                product: "product_12345",
                metadata: {
                  group_name: group_name,
                },
              )
          end

          it "does not add the user to the group when subscription fails" do
            ::Stripe::SubscriptionService
              .any_instance
              .expects(:create)
              .with(anything)
              .returns(status: "failed")

            expect {
              post "/s/create.json", params: { plan: "plan_1234", source: "tok_1234" }
            }.not_to change { group.users.count }

            expect(user.groups).to be_empty
          end

          it "adds the user to the group when the subscription is active" do
            ::Stripe::SubscriptionService
              .any_instance
              .expects(:create)
              .with(anything)
              .returns(status: "active")

            expect {
              post "/s/create.json", params: { plan: "plan_1234", source: "tok_1234" }
            }.to change { group.users.count }

            expect(user.groups).not_to be_empty
          end

          it "adds the user to the group when the subscription is trialing" do
            ::Stripe::SubscriptionService
              .any_instance
              .expects(:create)
              .with(anything)
              .returns(status: "trialing")

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
