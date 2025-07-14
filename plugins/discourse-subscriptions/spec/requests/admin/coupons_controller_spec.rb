# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseSubscriptions::Admin::CouponsController do
  before { SiteSetting.discourse_subscriptions_enabled = true }

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
    let(:admin) { Fabricate(:admin) }

    before { sign_in(admin) }

    describe "#index" do
      it "returns a list of promo codes" do
        ::Stripe::PromotionCode
          .expects(:list)
          .with({ limit: 100 })
          .returns({ data: [{ id: "promo_123", coupon: { valid: true } }] })

        get "/s/admin/coupons.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body[0]["id"]).to eq("promo_123")
      end

      it "only returns valid promo codes" do
        ::Stripe::PromotionCode
          .expects(:list)
          .with({ limit: 100 })
          .returns({ data: [{ id: "promo_123", coupon: { valid: false } }] })

        get "/s/admin/coupons.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body).to be_blank
      end
    end

    describe "#create" do
      it "creates a coupon with an amount off" do
        ::Stripe::Coupon.expects(:create).returns(id: "coup_123")
        ::Stripe::PromotionCode.expects(:create).returns(
          { code: "p123", coupon: { amount_off: 2000 } },
        )

        post "/s/admin/coupons.json",
             params: {
               promo: "p123",
               discount_type: "amount",
               discount: "2000",
               active: true,
             }
        expect(response.status).to eq(200)
        expect(response.parsed_body["code"]).to eq("p123")
        expect(response.parsed_body["coupon"]["amount_off"]).to eq(2000)
      end

      it "creates a coupon with a percent off" do
        ::Stripe::Coupon.expects(:create).returns(id: "coup_123")
        ::Stripe::PromotionCode.expects(:create).returns(
          { code: "p123", coupon: { percent_off: 20 } },
        )

        post "/s/admin/coupons.json",
             params: {
               promo: "p123",
               discount_type: "percent",
               discount: "20",
               active: true,
             }
        expect(response.status).to eq(200)
        expect(response.parsed_body["code"]).to eq("p123")
        expect(response.parsed_body["coupon"]["percent_off"]).to eq(20)
      end
    end
  end
end
