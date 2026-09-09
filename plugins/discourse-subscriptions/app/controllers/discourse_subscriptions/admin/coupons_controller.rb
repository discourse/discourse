# frozen_string_literal: true

module DiscourseSubscriptions
  module Admin
    class CouponsController < ::Admin::AdminController
      include DiscourseSubscriptions::Stripe
      include DiscourseSubscriptions::Group

      requires_plugin PLUGIN_NAME

      def index
        promo_codes = nil

        if is_stripe_configured?
          promo_codes =
            stripe_client.v1.promotion_codes.list({ limit: 100 })[:data].select do |code|
              code[:coupon][:valid] == true
            end
        end

        render_json_dump promo_codes
      rescue ::Stripe::InvalidRequestError => e
        render_json_error e.message
      end

      def create
        params.require(%i[promo discount_type discount active])
        begin
          coupon_params = { duration: "forever" }

          case params[:discount_type]
          when "amount"
            coupon_params[:amount_off] = params[:discount].to_i * 100
            coupon_params[:currency] = SiteSetting.discourse_subscriptions_currency
          when "percent"
            coupon_params[:percent_off] = params[:discount]
          end

          coupon = stripe_client.v1.coupons.create(coupon_params)

          promo_code =
            stripe_client.v1.promotion_codes.create(
              { coupon: coupon[:id], code: params[:promo] },
            ) if coupon.present?

          render_json_dump promo_code
        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
      end

      def update
        params.require(%i[id active])
        begin
          promo_code =
            stripe_client.v1.promotion_codes.update(params[:id], { active: params[:active] })

          render_json_dump promo_code
        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
      end

      def destroy
        params.require(:coupon_id)
        begin
          coupon = stripe_client.v1.coupons.delete(params[:coupon_id], {})
          render_json_dump coupon
        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
      end
    end
  end
end
