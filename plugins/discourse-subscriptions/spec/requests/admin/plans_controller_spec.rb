# frozen_string_literal: true

RSpec.describe DiscourseSubscriptions::Admin::PlansController, :setup_stripe_mock do
  before { setup_discourse_subscriptions }

  it "is a subclass of AdminController" do
    expect(DiscourseSubscriptions::Admin::PlansController < ::Admin::AdminController).to eq(true)
  end

  context "when not authenticated" do
    describe "index" do
      it "does not get the plans" do
        ::Stripe::Price.expects(:list).never
        get "/s/admin/plans.json"
        expect(response.status).to eq(404)
      end
    end

    describe "create" do
      it "does not create a plan" do
        ::Stripe::Price.expects(:create).never
        post "/s/admin/plans.json", params: { name: "Rick Astley", amount: 1, interval: "week" }
        expect(response.status).to eq(404)
      end
    end

    describe "show" do
      it "does not show the plan" do
        ::Stripe::Price.expects(:retrieve).never
        get "/s/admin/plans/plan_12345.json"
        expect(response.status).to eq(404)
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
    fab!(:admin)

    before { sign_in(admin) }

    describe "index" do
      it "lists the plans" do
        product = ::Stripe::Product.create(name: "Index Product", type: "service")
        price1 = ::Stripe::Price.create(product: product.id, unit_amount: 500, currency: "usd")
        price2 =
          ::Stripe::Price.create(
            product: product.id,
            unit_amount: 1500,
            currency: "usd",
            recurring: {
              interval: "month",
            },
          )

        get "/s/admin/plans.json"
        expect(response.status).to eq(200)

        plans = response.parsed_body
        expect(plans.length).to be >= 2

        plan1 = plans.find { |p| p["id"] == price1.id }
        expect(plan1["unit_amount"]).to eq(500)
        expect(plan1["product"]).to eq(product.id)

        plan2 = plans.find { |p| p["id"] == price2.id }
        expect(plan2["unit_amount"]).to eq(1500)
        expect(plan2["recurring"]["interval"]).to eq("month")
      end

      it "lists the plans for the product" do
        product = ::Stripe::Product.create(name: "Filtered Product", type: "service")
        price1 = ::Stripe::Price.create(product: product.id, unit_amount: 700, currency: "usd")
        price2 =
          ::Stripe::Price.create(
            product: product.id,
            unit_amount: 900,
            currency: "usd",
            recurring: {
              interval: "year",
            },
          )

        get "/s/admin/plans.json", params: { product_id: product.id }
        expect(response.status).to eq(200)

        plans = response.parsed_body
        ids = plans.map { |p| p["id"] }
        expect(ids).to include(price1.id, price2.id)
      end
    end

    describe "show" do
      it "shows a plan and upcases the currency" do
        product = ::Stripe::Product.create(name: "Show Product", type: "service")
        price =
          ::Stripe::Price.create(
            product: product.id,
            unit_amount: 1220,
            currency: "aud",
            recurring: {
              interval: "year",
            },
          )

        get "/s/admin/plans/#{price.id}.json"
        expect(response.status).to eq(200)

        plan = response.parsed_body
        expect(plan["currency"]).to eq("AUD")
        expect(plan["interval"]).to eq("year")
      end
    end

    describe "create" do
      it "creates a recurring plan with all attributes" do
        product = ::Stripe::Product.create(name: "Recurring Product", type: "service")

        post "/s/admin/plans.json",
             params: {
               nickname: "Monthly Plan",
               currency: "usd",
               type: "recurring",
               interval: "month",
               amount: "1500",
               product: product.id,
               active: "true",
               metadata: {
                 group_name: "",
               },
             }
        expect(response.status).to eq(200)

        body = response.parsed_body
        expect(body["nickname"]).to eq("Monthly Plan")
        expect(body["unit_amount"]).to eq("1500")
        expect(body["currency"]).to eq("usd")
        expect(body["recurring"]["interval"]).to eq("month")
        expect(body["product"]).to eq(product.id)
      end

      it "creates a one-time plan" do
        product = ::Stripe::Product.create(name: "One Time Product", type: "service")

        post "/s/admin/plans.json",
             params: {
               nickname: "One Time",
               currency: "usd",
               amount: "2000",
               product: product.id,
               metadata: {
                 group_name: "",
               },
             }
        expect(response.status).to eq(200)

        body = response.parsed_body
        expect(body["nickname"]).to eq("One Time")
        expect(body["product"]).to eq(product.id)
      end
    end

    describe "update" do
      it "updates a plan" do
        product = ::Stripe::Product.create(name: "Update Product", type: "service")
        price =
          ::Stripe::Price.create(
            product: product.id,
            unit_amount: 1000,
            currency: "usd",
            nickname: "Original Nickname",
          )

        patch "/s/admin/plans/#{price.id}.json",
              params: {
                nickname: "Updated Nickname",
                metadata: {
                  group_name: "some-group",
                },
                trial_period_days: "14",
              }
        expect(response.status).to eq(200)

        body = response.parsed_body
        expect(body["nickname"]).to eq("Updated Nickname")
        expect(body["metadata"]["group_name"]).to eq("some-group")
        expect(body["metadata"]["trial_period_days"]).to eq("14")
      end
    end
  end
end
