# frozen_string_literal: true

module DiscourseSubscriptions
  module Admin
    class CouponsController < ::Admin::AdminController
      include DiscourseSubscriptions::Stripe
      include DiscourseSubscriptions::Group

      requires_plugin PLUGIN_NAME

      def index
        begin
          promo_codes = ::Stripe::PromotionCode.list({ limit: 100 }, stripe_request_opts)[:data]
          promo_codes = promo_codes.select { |code| code[:coupon][:valid] == true }
          render_json_dump promo_codes
        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
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

          coupon = ::Stripe::Coupon.create(coupon_params, stripe_request_opts)

          promo_code =
            ::Stripe::PromotionCode.create(
              { coupon: coupon[:id], code: params[:promo] },
              stripe_request_opts,
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
            ::Stripe::PromotionCode.update(
              params[:id],
              { active: params[:active] },
              stripe_request_opts,
            )

          render_json_dump promo_code
        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
      end

      def destroy
        params.require(:coupon_id)
        begin
          coupon = ::Stripe::Coupon.delete(params[:coupon_id], {}, stripe_request_opts)
          render_json_dump coupon
        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
      end
    end
  end
end
