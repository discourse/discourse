# frozen_string_literal: true

RSpec.describe DiscourseSubscriptions::Admin::CouponsController, :setup_stripe_mock do
  before { setup_discourse_subscriptions }

  it "is a subclass of AdminController" do
    expect(DiscourseSubscriptions::Admin::CouponsController < ::Admin::AdminController).to eq(true)
  end

  context "when unauthenticated" do
    it "does nothing" do
      ::Stripe::PromotionCode.expects(:list).never
      get "/s/admin/coupons.json"
      expect(response.status).to eq(404)
    end
  end

  context "when authenticated" do
    fab!(:admin)

    before { sign_in(admin) }

    describe "#index" do
      it "returns a list of promo codes" do
        coupon1 = ::Stripe::Coupon.create(duration: "forever", percent_off: 10.0)
        coupon2 = ::Stripe::Coupon.create(duration: "forever", percent_off: 25.0)

        ::Stripe::PromotionCode.create(coupon: coupon1.to_h, code: "TESTLIST1")
        ::Stripe::PromotionCode.create(coupon: coupon2.to_h, code: "TESTLIST2")

        get "/s/admin/coupons.json"
        expect(response.status).to eq(200)

        data = response.parsed_body
        expect(data.size).to eq(2)

        codes = data.map { |d| d["code"] }
        expect(codes).to contain_exactly("TESTLIST1", "TESTLIST2")

        entry1 = data.find { |d| d["code"] == "TESTLIST1" }
        expect(entry1["coupon"]["percent_off"]).to eq(10.0)
        expect(entry1["coupon"]["valid"]).to eq(true)

        entry2 = data.find { |d| d["code"] == "TESTLIST2" }
        expect(entry2["coupon"]["percent_off"]).to eq(25.0)
        expect(entry2["coupon"]["valid"]).to eq(true)
      end
    end

    describe "#create" do
      it "creates a coupon with an amount off" do
        post "/s/admin/coupons.json",
             params: {
               promo: "AMTOFF20",
               discount_type: "amount",
               discount: "20",
               active: true,
             }

        expect(response.status).to eq(200)
        expect(response.parsed_body["code"]).to eq("AMTOFF20")

        coupon = ::Stripe::Coupon.retrieve(response.parsed_body["coupon"])
        expect(coupon.amount_off).to eq(2000)
      end

      it "creates a coupon with a percent off" do
        post "/s/admin/coupons.json",
             params: {
               promo: "PCTOFF20",
               discount_type: "percent",
               discount: "20",
               active: true,
             }

        expect(response.status).to eq(200)
        expect(response.parsed_body["code"]).to eq("PCTOFF20")

        coupon = ::Stripe::Coupon.retrieve(response.parsed_body["coupon"])
        expect(coupon.percent_off).to eq("20")
      end
    end
  end
end
