# frozen_string_literal: true

describe DiscourseSubscriptions::Campaign, :setup_stripe_mock do
  describe "campaign data is refreshed" do
    fab!(:user)
    fab!(:user2, :user)

    before do
      setup_discourse_subscriptions
      SiteSetting.discourse_subscriptions_public_key = "public-key"
    end

    def create_subscription_with_product(product_id:, unit_amount:, interval:)
      stripe_product = ::Stripe::Product.create(name: product_id, type: "service")
      stripe_price =
        ::Stripe::Price.create(
          product: stripe_product.id,
          unit_amount: unit_amount,
          currency: "usd",
          recurring: {
            interval: interval,
          },
        )
      stripe_customer =
        ::Stripe::Customer.create(email: "test@example.com", source: StripeMock.generate_card_token)
      ::Stripe::Subscription.create(
        customer: stripe_customer.id,
        items: [{ price: stripe_price.id }],
      )
      stripe_product.id
    end

    describe "refresh_data" do
      it "refreshes the campaign data properly" do
        stripe_product_id =
          create_subscription_with_product(
            product_id: "Campaign Product",
            unit_amount: 2000,
            interval: "month",
          )
        Fabricate(:product, external_id: stripe_product_id)
        Fabricate(:customer, product_id: stripe_product_id, user_id: user.id, customer_id: "cus_1")

        DiscourseSubscriptions::Campaign.new.refresh_data

        expect(SiteSetting.discourse_subscriptions_campaign_subscribers).to eq(1)
        expect(SiteSetting.discourse_subscriptions_campaign_amount_raised).to eq(20.0)
      end

      it "checks if the goal is completed" do
        stripe_product_id =
          create_subscription_with_product(
            product_id: "Goal Product",
            unit_amount: 2000,
            interval: "month",
          )
        Fabricate(:product, external_id: stripe_product_id)
        Fabricate(:customer, product_id: stripe_product_id, user_id: user.id, customer_id: "cus_2")

        SiteSetting.discourse_subscriptions_campaign_type = "Amount"
        SiteSetting.discourse_subscriptions_campaign_goal = 5

        DiscourseSubscriptions::Campaign.new.refresh_data
        expect(Discourse.redis.get("subscriptions_goal_met_date")).to be_present
      end

      it "clears goal flag when goal drops below 90%" do
        stripe_product_id =
          create_subscription_with_product(
            product_id: "Low Goal Product",
            unit_amount: 100,
            interval: "month",
          )
        Fabricate(:product, external_id: stripe_product_id)
        Fabricate(:customer, product_id: stripe_product_id, user_id: user.id, customer_id: "cus_3")

        SiteSetting.discourse_subscriptions_campaign_type = "Subscribers"
        SiteSetting.discourse_subscriptions_campaign_goal = 25
        Discourse.redis.set("subscriptions_goal_met_date", 10.days.ago)

        DiscourseSubscriptions::Campaign.new.refresh_data
        expect(Discourse.redis.get("subscriptions_goal_met_date")).to be_blank
      end

      context "with a campaign product set" do
        it "refreshes campaign data with only the campaign product" do
          stripe_product1_id =
            create_subscription_with_product(
              product_id: "Main Product",
              unit_amount: 1000,
              interval: "month",
            )
          stripe_product2_id =
            create_subscription_with_product(
              product_id: "Other Product",
              unit_amount: 5000,
              interval: "month",
            )
          Fabricate(:product, external_id: stripe_product1_id)
          Fabricate(:product, external_id: stripe_product2_id)
          Fabricate(
            :customer,
            product_id: stripe_product1_id,
            user_id: user.id,
            customer_id: "cus_4",
          )
          Fabricate(
            :customer,
            product_id: stripe_product2_id,
            user_id: user2.id,
            customer_id: "cus_5",
          )

          SiteSetting.discourse_subscriptions_campaign_product = stripe_product1_id

          DiscourseSubscriptions::Campaign.new.refresh_data

          expect(SiteSetting.discourse_subscriptions_campaign_subscribers).to eq(1)
        end
      end
    end
  end

  describe "campaign is automatically created" do
    describe "create_campaign" do
      it "successfully creates the campaign group, product, and prices" do
        ::Stripe::Product.expects(:create).returns(id: "prod_campaign")
        ::Stripe::Price.expects(:create).times(6)

        DiscourseSubscriptions::Campaign.new.create_campaign

        group = Group.find_by(name: "campaign_supporters")

        expect(group[:full_name]).to eq("Supporters")
        expect(SiteSetting.discourse_subscriptions_campaign_group.to_i).to eq(group.id)

        expect(DiscourseSubscriptions::Product.where(external_id: "prod_campaign").length).to eq(1)

        expect(SiteSetting.discourse_subscriptions_campaign_enabled).to eq(true)
        expect(SiteSetting.discourse_subscriptions_campaign_product).to eq("prod_campaign")
      end
    end
  end
end
