# frozen_string_literal: true

require "rails_helper"

describe DiscourseSubscriptions::Campaign do
  describe "campaign data is refreshed" do
    let(:user) { Fabricate(:user) }
    let(:user2) { Fabricate(:user) }
    let(:subscription) do
      {
        id: "sub_1234",
        items: {
          data: [
            {
              price: {
                product: "prodct_23456",
                unit_amount: 1000,
                recurring: {
                  interval: "month",
                },
              },
            },
          ],
        },
      }
    end
    let(:invoice) do
      {
        id: "in_1234",
        paid: true,
        lines: {
          data: [
            {
              plan: nil,
              price: {
                product: "prodct_65432",
                active: true,
                unit_amount: 1000,
                recurring: nil,
              },
            },
          ],
        },
      }
    end
    let(:invoice2) do
      {
        id: "in_1235",
        paid: false,
        lines: {
          data: [
            {
              plan: nil,
              price: {
                product: "prodct_65433",
                active: true,
                unit_amount: 600,
                recurring: nil,
              },
            },
          ],
        },
      }
    end
    let(:invoice_with_nil_lines) { { id: "in_1236", paid: true, lines: nil } }
    let(:invoice_with_nil_price) do
      { id: "in_1237", paid: true, lines: { data: [{ plan: nil, price: nil }] } }
    end

    before do
      Fabricate(:product, external_id: "prodct_23456")
      Fabricate(:customer, product_id: "prodct_23456", user_id: user.id, customer_id: "x")
      Fabricate(:product, external_id: "prodct_65432")
      Fabricate(:customer, product_id: "prodct_65432", user_id: user2.id, customer_id: "y")
      Fabricate(:product, external_id: "prodct_65433")
      Fabricate(:customer, product_id: "prodct_65433", user_id: user2.id, customer_id: "y")
      SiteSetting.discourse_subscriptions_public_key = "public-key"
      SiteSetting.discourse_subscriptions_secret_key = "secret-key"
    end

    describe "refresh_data" do
      context "for all subscription purchases" do
        it "refreshes the campaign data properly" do
          ::Stripe::Subscription.expects(:list).returns(data: [subscription], has_more: false)
          ::Stripe::Invoice.expects(:list).returns(data: [invoice, invoice2], has_more: false)

          DiscourseSubscriptions::Campaign.new.refresh_data

          expect(SiteSetting.discourse_subscriptions_campaign_subscribers).to eq 1
          expect(SiteSetting.discourse_subscriptions_campaign_amount_raised).to eq 20.00
        end

        it "checks if the goal is completed or not" do
          SiteSetting.discourse_subscriptions_campaign_goal = 5
          ::Stripe::Subscription.expects(:list).returns(data: [subscription], has_more: false)
          ::Stripe::Invoice.expects(:list).returns(data: [invoice], has_more: false)

          DiscourseSubscriptions::Campaign.new.refresh_data
          expect(Discourse.redis.get("subscriptions_goal_met_date")).to be_present
        end

        it "checks if goal is < 90% met after being met" do
          SiteSetting.discourse_subscriptions_campaign_goal = 25
          Discourse.redis.set("subscriptions_goal_met_date", 10.days.ago)
          ::Stripe::Subscription.expects(:list).returns(data: [subscription], has_more: false)
          ::Stripe::Invoice.expects(:list).returns(data: [invoice], has_more: false)

          DiscourseSubscriptions::Campaign.new.refresh_data
          expect(Discourse.redis.get("subscriptions_goal_met_date")).to be_blank
        end

        it "handles invoices with nil lines gracefully" do
          ::Stripe::Subscription.expects(:list).returns(data: [subscription], has_more: false)
          ::Stripe::Invoice.expects(:list).returns(data: [invoice_with_nil_lines], has_more: false)

          expect { DiscourseSubscriptions::Campaign.new.refresh_data }.not_to raise_error
        end

        it "handles invoices with nil price gracefully" do
          ::Stripe::Subscription.expects(:list).returns(data: [subscription], has_more: false)
          ::Stripe::Invoice.expects(:list).returns(data: [invoice_with_nil_price], has_more: false)

          expect { DiscourseSubscriptions::Campaign.new.refresh_data }.not_to raise_error
        end
      end

      context "with a campaign product set" do
        let(:user2) { Fabricate(:user) }
        let(:campaign_subscription) do
          {
            id: "sub_5678",
            items: {
              data: [
                {
                  price: {
                    product: "prod_use",
                    unit_amount: 10_000,
                    recurring: {
                      interval: "year",
                    },
                  },
                },
              ],
            },
          }
        end

        before do
          Fabricate(:product, external_id: "prod_use")
          Fabricate(:customer, product_id: "prod_use", user_id: user2.id, customer_id: "y")
          SiteSetting.discourse_subscriptions_campaign_product = "prod_use"
        end

        it "refreshes campaign data with only the campaign product/subscriptions" do
          ::Stripe::Subscription.expects(:list).returns(
            data: [subscription, campaign_subscription],
            has_more: false,
          )
          ::Stripe::Invoice.expects(:list).returns(data: [invoice], has_more: false)

          DiscourseSubscriptions::Campaign.new.refresh_data

          expect(SiteSetting.discourse_subscriptions_campaign_subscribers).to eq 1
          expect(SiteSetting.discourse_subscriptions_campaign_amount_raised).to eq 8.33
        end
      end
    end
  end

  describe "campaign is automatically created" do
    describe "create_campaign" do
      it "successfully creates the campaign group, product, and prices" do
        ::Stripe::Product.expects(:create).returns(id: "prod_campaign")
        ::Stripe::Price.expects(:create)
        ::Stripe::Price.expects(:create)
        ::Stripe::Price.expects(:create)
        ::Stripe::Price.expects(:create)
        ::Stripe::Price.expects(:create)
        ::Stripe::Price.expects(:create)

        DiscourseSubscriptions::Campaign.new.create_campaign

        group = Group.find_by(name: "campaign_supporters")

        expect(group[:full_name]).to eq "Supporters"
        expect(SiteSetting.discourse_subscriptions_campaign_group.to_i).to eq group.id

        expect(DiscourseSubscriptions::Product.where(external_id: "prod_campaign").length).to eq 1

        expect(SiteSetting.discourse_subscriptions_campaign_enabled).to eq true
        expect(SiteSetting.discourse_subscriptions_campaign_product).to eq "prod_campaign"
      end
    end
  end
end
