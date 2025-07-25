# frozen_string_literal: true

module DiscourseSubscriptions
  module User
    class SubscriptionsController < ::ApplicationController
      include DiscourseSubscriptions::Stripe
      include DiscourseSubscriptions::Group

      requires_plugin DiscourseSubscriptions::PLUGIN_NAME

      before_action :set_api_key
      requires_login

      def index
        begin
          customer = Customer.where(user_id: current_user.id)
          customer_ids = customer.map { |c| c.id } if customer
          stripe_customer_ids = customer.map { |c| c.customer_id }.uniq if customer
          subscription_ids =
            Subscription.where("customer_id in (?)", customer_ids).pluck(
              :external_id,
            ) if customer_ids

          subscriptions = []

          if subscription_ids
            prices = []
            price_params = { limit: 100, expand: ["data.product"] }
            loop do
              response = ::Stripe::Price.list(price_params)
              prices.concat(response[:data])
              break unless response[:has_more]
              price_params[:starting_after] = response[:data].last.id
            end
            all_subscriptions = []

            stripe_customer_ids.each do |stripe_customer_id|
              customer_subscriptions =
                ::Stripe::Subscription.list(customer: stripe_customer_id, status: "all")
              all_subscriptions.concat(customer_subscriptions[:data])
            end

            subscriptions = all_subscriptions.select { |sub| subscription_ids.include?(sub[:id]) }
            subscriptions.map! do |subscription|
              plan = prices.find { |p| p[:id] == subscription[:items][:data][0][:price][:id] }
              subscription.to_h.except!(:plan)
              subscription.to_h.merge(plan: plan, product: plan[:product].to_h.slice(:id, :name))
            end
          end

          render_json_dump subscriptions
        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
      end

      def destroy
        # we cancel but don't remove until the end of the period
        # full removal is done via webhooks
        begin
          subscription = ::Stripe::Subscription.update(params[:id], { cancel_at_period_end: true })

          if subscription
            render_json_dump subscription
          else
            render_json_error I18n.t("discourse_subscriptions.customer_not_found")
          end
        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
      end

      def update
        params.require(:payment_method)

        subscription = Subscription.where(external_id: params[:id]).first
        begin
          attach_method_to_customer(subscription.customer_id, params[:payment_method])
          subscription =
            ::Stripe::Subscription.update(
              params[:id],
              { default_payment_method: params[:payment_method] },
            )
          render json: success_json
        rescue ::Stripe::InvalidRequestError
          render_json_error I18n.t("discourse_subscriptions.card.invalid")
        end
      end

      private

      def attach_method_to_customer(customer_id, method)
        customer = Customer.find(customer_id)
        ::Stripe::PaymentMethod.attach(method, { customer: customer.customer_id })
      end
    end
  end
end
