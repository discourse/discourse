# frozen_string_literal: true

RSpec.describe DiscourseSubscriptions::SubscribeController, :setup_stripe_mock do
  let(:user) { Fabricate(:user) }
  let(:campaign_user) { Fabricate(:user) }

  before { setup_discourse_subscriptions }

  context "when showing products" do
    before do
      sign_in(user)
      SiteSetting.discourse_subscriptions_public_key = "public-key"
    end

    describe "#index" do
      it "gets products" do
        product1 =
          ::Stripe::Product.create(
            name: "Index Product 1",
            type: "service",
            metadata: {
              description: "First product",
            },
          )
        product2 =
          ::Stripe::Product.create(
            name: "Index Product 2",
            type: "service",
            metadata: {
              description: "Second product",
            },
          )

        Fabricate(:product, external_id: product1.id)
        Fabricate(:product, external_id: product2.id)

        get "/s.json"
        expect(response.status).to eq(200)

        data = response.parsed_body
        expect(data.length).to eq(2)

        p1 = data.find { |d| d["id"] == product1.id }
        expect(p1["name"]).to eq("Index Product 1")
        expect(p1["subscribed"]).to eq(false)

        p2 = data.find { |d| d["id"] == product2.id }
        expect(p2["name"]).to eq("Index Product 2")
        expect(p2["subscribed"]).to eq(false)
      end

      it "shows subscribed status when user has active subscription" do
        product =
          ::Stripe::Product.create(
            name: "Subscribed Product",
            type: "service",
            metadata: {
              description: "Subscribed test",
            },
          )

        Fabricate(:product, external_id: product.id)
        dc = Fabricate(:customer, product_id: product.id, user_id: user.id, customer_id: "x")
        Fabricate(:subscription, external_id: "sub_test", customer_id: dc.id, status: nil)

        get "/s.json"
        expect(response.parsed_body.first["subscribed"]).to eq(true)
      end
    end

    describe "#get_contributors" do
      before do
        Fabricate(:product, external_id: "prod_contrib_1")
        Fabricate(:product, external_id: "prod_contrib_2")
        Fabricate(:customer, product_id: "prod_contrib_1", user_id: user.id, customer_id: "x")
        Fabricate(
          :customer,
          product_id: "prod_contrib_2",
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
          SiteSetting.discourse_subscriptions_campaign_product = "prod_contrib_2"

          get "/s/contributors.json"

          data = response.parsed_body
          expect(data.first["id"]).to eq(campaign_user.id)
          expect(data.length).to eq(1)
        end

        it "shows all purchases if campaign product not set" do
          SiteSetting.discourse_subscriptions_campaign_product = nil

          get "/s/contributors.json"

          data = response.parsed_body
          expect(data.length).to eq(2)
        end
      end
    end

    describe "#show" do
      it "retrieves the product with plans" do
        product =
          ::Stripe::Product.create(
            name: "Show Product",
            type: "service",
            metadata: {
              description: "Show product description",
            },
          )
        ::Stripe::Price.create(
          product: product.id,
          unit_amount: 1220,
          currency: "aud",
          recurring: {
            interval: "year",
          },
        )
        ::Stripe::Price.create(
          product: product.id,
          unit_amount: 1399,
          currency: "usd",
          recurring: {
            interval: "year",
          },
        )

        Fabricate(:product, external_id: product.id)

        get "/s/#{product.id}.json"
        expect(response.status).to eq(200)

        body = response.parsed_body
        expect(body["product"]["name"]).to eq("Show Product")
        expect(body["plans"].length).to eq(2)
        expect(body["plans"].map { |p| p["type"] }).to all(eq("recurring"))
      end
    end
  end

  context "when creating subscriptions" do
    context "when unauthenticated" do
      it "does not create a subscription" do
        ::Stripe::Customer.expects(:create).never
        ::Stripe::Price.expects(:retrieve).never
        ::Stripe::Subscription.expects(:create).never
        post "/s/create.json", params: { plan: "plan_1234", source: "tok_visa" }
      end
    end

    context "when authenticated" do
      before { sign_in(user) }

      describe "#create" do
        it "creates a recurring subscription" do
          product = ::Stripe::Product.create(name: "Recurring Sub Product", type: "service")
          price =
            ::Stripe::Price.create(
              product: product.id,
              unit_amount: 1000,
              currency: "usd",
              recurring: {
                interval: "month",
              },
              metadata: {
                group_name: "",
              },
            )

          expect {
            post "/s/create.json",
                 params: {
                   plan: price.id,
                   source: StripeMock.generate_card_token,
                 }
          }.to change { DiscourseSubscriptions::Customer.count }

          expect(response.status).to eq(200)
        end

        it "creates a one-time payment" do
          ::Stripe::Customer.stubs(:create).returns(id: "cus_otp")
          ::Stripe::Price.stubs(:retrieve).returns(
            id: "price_otp",
            type: "one_time",
            product: "prod_otp",
            metadata: {
              group_name: "",
            },
          )
          ::Stripe::Invoice.stubs(:create).returns(id: "in_otp")
          ::Stripe::InvoiceItem.stubs(:create).returns(id: "ii_otp")
          ::Stripe::Invoice.stubs(:finalize_invoice).returns(
            id: "in_otp",
            status: "open",
            customer: "cus_otp",
          )
          ::Stripe::Invoice.stubs(:retrieve).returns(id: "in_otp", payment_intent: "pi_otp")
          ::Stripe::PaymentIntent.stubs(:retrieve).returns(id: "pi_otp", status: "successful")
          ::Stripe::Invoice.stubs(:pay).returns(id: "in_otp", status: "paid", customer: "cus_otp")

          expect {
            post "/s/create.json", params: { plan: "price_otp", source: "tok_visa" }
          }.to change { DiscourseSubscriptions::Customer.count }
        end

        it "reuses existing stripe customer on subsequent purchase" do
          product = ::Stripe::Product.create(name: "Reuse Customer Product", type: "service")
          price1 =
            ::Stripe::Price.create(
              product: product.id,
              unit_amount: 1000,
              currency: "usd",
              recurring: {
                interval: "month",
              },
              metadata: {
                group_name: "",
              },
            )
          price2 =
            ::Stripe::Price.create(
              product: product.id,
              unit_amount: 2000,
              currency: "usd",
              recurring: {
                interval: "month",
              },
              metadata: {
                group_name: "",
              },
            )

          expect {
            post "/s/create.json",
                 params: {
                   plan: price1.id,
                   source: StripeMock.generate_card_token,
                 }
          }.to change { DiscourseSubscriptions::Customer.count }.by(1)

          first_customer_id = DiscourseSubscriptions::Customer.last.customer_id

          expect {
            post "/s/create.json",
                 params: {
                   plan: price2.id,
                   source: StripeMock.generate_card_token,
                 }
          }.to change { DiscourseSubscriptions::Customer.count }.by(1)

          expect(DiscourseSubscriptions::Customer.last.customer_id).to eq(first_customer_id)
        end

        context "with customer name & address" do
          it "creates a customer & subscription when a customer address is provided" do
            product = ::Stripe::Product.create(name: "Address Product", type: "service")
            price =
              ::Stripe::Price.create(
                product: product.id,
                unit_amount: 1000,
                currency: "usd",
                recurring: {
                  interval: "month",
                },
                metadata: {
                  group_name: "",
                },
              )

            expect {
              post "/s/create.json",
                   params: {
                     plan: price.id,
                     source: StripeMock.generate_card_token,
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
              product = ::Stripe::Product.create(name: "Promo Invalid Product", type: "service")
              price =
                ::Stripe::Price.create(
                  product: product.id,
                  unit_amount: 1000,
                  currency: "usd",
                  recurring: {
                    interval: "month",
                  },
                  metadata: {
                    group_name: "",
                  },
                )

              post "/s/create.json",
                   params: {
                     plan: price.id,
                     source: StripeMock.generate_card_token,
                     promo: "nonexistent_code",
                   }

              data = response.parsed_body
              expect(data["errors"]).not_to be_blank
            end
          end

          context "with valid code" do
            it "applies promo code to recurring subscription" do
              product = ::Stripe::Product.create(name: "Promo Recurring Product", type: "service")
              price =
                ::Stripe::Price.create(
                  product: product.id,
                  unit_amount: 1000,
                  currency: "usd",
                  recurring: {
                    interval: "month",
                  },
                  metadata: {
                    group_name: "",
                  },
                )
              code = "PROMORECUR"
              coupon = ::Stripe::Coupon.create(duration: "forever", percent_off: 10)
              existing = ::Stripe::PromotionCode.list(code: code, active: true)
              existing.data.each do |promo|
                ::Stripe::PromotionCode.update(promo.id, { active: false })
              end
              ::Stripe::PromotionCode.create(coupon: coupon.id, code: code)

              expect {
                post "/s/create.json",
                     params: {
                       plan: price.id,
                       source: StripeMock.generate_card_token,
                       promo: code,
                     }
              }.to change { DiscourseSubscriptions::Customer.count }
            end

            it "applies promo code to one time purchase" do
              ::Stripe::Customer.stubs(:create).returns(id: "cus_promo_otp")
              ::Stripe::Price.stubs(:retrieve).returns(
                id: "price_promo_otp",
                type: "one_time",
                product: "prod_promo_otp",
                metadata: {
                  group_name: "",
                },
              )
              ::Stripe::PromotionCode.stubs(:list).returns(
                data: [{ id: "promo_otp", coupon: { id: "coupon_otp" } }],
              )
              ::Stripe::Invoice.stubs(:create).returns(id: "in_promo_otp")
              ::Stripe::InvoiceItem.stubs(:create).returns(id: "ii_promo_otp")
              ::Stripe::Invoice.stubs(:finalize_invoice).returns(
                id: "in_promo_otp",
                status: "open",
                customer: "cus_promo_otp",
              )
              ::Stripe::Invoice.stubs(:retrieve).returns(
                id: "in_promo_otp",
                payment_intent: "pi_promo_otp",
              )
              ::Stripe::PaymentIntent.stubs(:retrieve).returns(
                id: "pi_promo_otp",
                status: "successful",
              )
              ::Stripe::Invoice.stubs(:pay).returns(
                id: "in_promo_otp",
                status: "paid",
                customer: "cus_promo_otp",
              )

              expect {
                post "/s/create.json",
                     params: {
                       plan: "price_promo_otp",
                       source: "tok_visa",
                       promo: "PROMOOTP",
                     }
              }.to change { DiscourseSubscriptions::Customer.count }
            end
          end
        end
      end

      describe "#finalize strong customer authenticated transaction" do
        context "with subscription" do
          it "finalizes the subscription" do
            product = ::Stripe::Product.create(name: "Finalize Recurring Product", type: "service")
            price =
              ::Stripe::Price.create(
                product: product.id,
                unit_amount: 1000,
                currency: "usd",
                recurring: {
                  interval: "month",
                },
                metadata: {
                  group_name: "",
                },
              )
            customer =
              ::Stripe::Customer.create(email: user.email, source: StripeMock.generate_card_token)
            subscription =
              ::Stripe::Subscription.create(
                customer: customer.id,
                items: [{ price: price.id }],
                id: "sub_finalize_test",
              )

            expect {
              post "/s/finalize.json", params: { plan: price.id, transaction: subscription.id }
            }.to change { DiscourseSubscriptions::Customer.count }
          end
        end

        context "with one-time payment" do
          it "finalizes the one-time payment" do
            ::Stripe::Price.stubs(:retrieve).returns(
              id: "price_fin_otp",
              type: "one_time",
              product: "prod_fin_otp",
              metadata: {
                group_name: "",
              },
            )
            ::Stripe::Invoice.stubs(:retrieve).returns(
              id: "in_fin_otp",
              status: "paid",
              customer: "cus_fin_otp",
              object: "invoice",
            )

            expect {
              post "/s/finalize.json", params: { plan: "price_fin_otp", transaction: "in_fin_otp" }
            }.to change { DiscourseSubscriptions::Customer.count }
          end
        end
      end

      describe "user groups" do
        it "adds the user to the group when the subscription is active" do
          group = Fabricate(:group, name: "sub-active-group")

          product = ::Stripe::Product.create(name: "Group Active Product", type: "service")
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
              },
            )

          expect {
            post "/s/create.json",
                 params: {
                   plan: price.id,
                   source: StripeMock.generate_card_token,
                 }
          }.to change { group.users.count }

          expect(user.groups).not_to be_empty
        end

        it "adds the user to the group when the subscription is trialing" do
          group = Fabricate(:group, name: "sub-trial-group")

          product = ::Stripe::Product.create(name: "Group Trial Product", type: "service")
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
                trial_period_days: "14",
              },
            )

          expect {
            post "/s/create.json",
                 params: {
                   plan: price.id,
                   source: StripeMock.generate_card_token,
                 }
          }.to change { group.users.count }

          expect(user.groups).not_to be_empty
        end

        it "does not add the user to the admins group" do
          ::Stripe::Customer.stubs(:create).returns(id: "cus_fake")
          ::Stripe::Price.stubs(:retrieve).returns(
            id: "price_fake",
            type: "recurring",
            product: "prod_fake",
            metadata: {
              group_name: "admins",
            },
          )
          ::Stripe::Subscription.stubs(:create).returns(
            id: "sub_fake",
            status: "active",
            customer: "cus_fake",
            object: "subscription",
          )

          post "/s/create.json", params: { plan: "price_fake", source: "tok_visa" }
          expect(user.admin).to eq(false)
        end
      end
    end
  end
end
