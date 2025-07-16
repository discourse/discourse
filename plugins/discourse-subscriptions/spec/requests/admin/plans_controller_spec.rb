# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseSubscriptions::Admin::PlansController do
  before { SiteSetting.discourse_subscriptions_enabled = true }

  it "is a subclass of AdminController" do
    expect(DiscourseSubscriptions::Admin::PlansController < ::Admin::AdminController).to eq(true)
  end

  context "when not authenticated" do
    describe "index" do
      it "does not get the plans" do
        ::Stripe::Price.expects(:list).never
        get "/s/admin/plans.json"
      end

      it "not ok" do
        get "/s/admin/plans.json"
        expect(response.status).to eq 404
      end
    end

    describe "create" do
      it "does not create a plan" do
        ::Stripe::Price.expects(:create).never
        post "/s/admin/plans.json", params: { name: "Rick Astley", amount: 1, interval: "week" }
      end

      it "is not ok" do
        post "/s/admin/plans.json", params: { name: "Rick Astley", amount: 1, interval: "week" }
        expect(response.status).to eq 404
      end
    end

    describe "show" do
      it "does not show the plan" do
        ::Stripe::Price.expects(:retrieve).never
        get "/s/admin/plans/plan_12345.json"
      end

      it "is not ok" do
        get "/s/admin/plans/plan_12345.json"
        expect(response.status).to eq 404
      end
    end

    describe "update" do
      it "does not update a plan" do
        ::Stripe::Price.expects(:update).never
        delete "/s/admin/plans/plan_12345.json"
      end
    end
  end

  context "when authenticated" do
    let(:admin) { Fabricate(:admin) }

    before { sign_in(admin) }

    describe "index" do
      it "lists the plans" do
        ::Stripe::Price.expects(:list).with(nil)
        get "/s/admin/plans.json"
      end

      it "lists the plans for the product" do
        ::Stripe::Price.expects(:list).with({ product: "prod_id123" })
        get "/s/admin/plans.json", params: { product_id: "prod_id123" }
      end
    end

    describe "show" do
      it "shows a plan" do
        ::Stripe::Price.expects(:retrieve).with("plan_12345").returns(currency: "aud")
        get "/s/admin/plans/plan_12345.json"
        expect(response.status).to eq 200
      end

      it "upcases the currency" do
        ::Stripe::Price
          .expects(:retrieve)
          .with("plan_12345")
          .returns(currency: "aud", recurring: { interval: "year" })
        get "/s/admin/plans/plan_12345.json"

        plan = response.parsed_body
        expect(plan["currency"]).to eq "AUD"
        expect(plan["interval"]).to eq "year"
      end
    end

    describe "create" do
      it "creates a plan with a nickname" do
        ::Stripe::Price.expects(:create).with(has_entry(:nickname, "Veg"))
        post "/s/admin/plans.json", params: { nickname: "Veg", metadata: { group_name: "" } }
      end

      it "creates a plan with a currency" do
        ::Stripe::Price.expects(:create).with(has_entry(:currency, "AUD"))
        post "/s/admin/plans.json", params: { currency: "AUD", metadata: { group_name: "" } }
      end

      it "creates a plan with an interval" do
        ::Stripe::Price.expects(:create).with(has_entry(recurring: { interval: "week" }))
        post "/s/admin/plans.json",
             params: {
               type: "recurring",
               interval: "week",
               metadata: {
                 group_name: "",
               },
             }
      end

      it "creates a plan as a one-time purchase" do
        ::Stripe::Price.expects(:create).with(Not(has_key(:recurring)))
        post "/s/admin/plans.json", params: { metadata: { group_name: "" } }
      end

      it "creates a plan with an amount" do
        ::Stripe::Price.expects(:create).with(has_entry(:unit_amount, "102"))
        post "/s/admin/plans.json", params: { amount: "102", metadata: { group_name: "" } }
      end

      it "creates a plan with a product" do
        ::Stripe::Price.expects(:create).with(has_entry(product: "prod_walterwhite"))
        post "/s/admin/plans.json",
             params: {
               product: "prod_walterwhite",
               metadata: {
                 group_name: "",
               },
             }
      end

      it "creates a plan with an active status" do
        ::Stripe::Price.expects(:create).with(has_entry(:active, "false"))
        post "/s/admin/plans.json", params: { active: "false", metadata: { group_name: "" } }
      end

      # TODO: Need to fix the metadata tests
      # I think mocha has issues with the metadata fields here.

      #it 'has metadata' do
      #  ::Stripe::Price.expects(:create).with(has_entry(:group_name, "discourse-user-group-name"))
      #  post "/s/admin/plans.json", params: { amount: "100", metadata: { group_name: 'discourse-user-group-name' } }
      #end

      #it "creates a plan with a trial period" do
      #  ::Stripe::Price.expects(:create).with(has_entry(trial_period_days: '14'))
      #  post "/s/admin/plans.json", params: { trial_period_days: '14' }
      #end
    end

    describe "update" do
      it "updates a plan" do
        ::Stripe::Price.expects(:update)
        patch "/s/admin/plans/plan_12345.json",
              params: {
                trial_period_days: "14",
                metadata: {
                  group_name: "discourse-user-group-name",
                },
              }
      end
    end
  end
end
