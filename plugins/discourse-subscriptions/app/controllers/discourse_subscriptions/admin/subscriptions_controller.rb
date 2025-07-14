# frozen_string_literal: true

module DiscourseSubscriptions
  module Admin
    class SubscriptionsController < ::Admin::AdminController
      requires_plugin DiscourseSubscriptions::PLUGIN_NAME

      include DiscourseSubscriptions::Stripe
      include DiscourseSubscriptions::Group
      before_action :set_api_key

      PAGE_LIMIT = 10

      def index
        begin
          subscription_ids = Subscription.all.pluck(:external_id)
          subscriptions = {
            has_more: false,
            data: [],
            length: 0,
            last_record: params[:last_record],
          }

          if subscription_ids.present? && is_stripe_configured?
            while subscriptions[:length] < PAGE_LIMIT
              current_set = get_subscriptions(subscriptions[:last_record])

              until valid_subscriptions =
                      find_valid_subscriptions(current_set[:data], subscription_ids)
                current_set = get_subscriptions(current_set[:data].last)
                break if current_set[:has_more] == false
              end

              subscriptions[:data] = subscriptions[:data].concat(valid_subscriptions.to_a)
              subscriptions[:last_record] = current_set[:data].last[:id] if current_set[
                :data
              ].present?
              subscriptions[:length] = subscriptions[:data].length
              subscriptions[:has_more] = current_set[:has_more]
              break if subscriptions[:has_more] == false
            end
          elsif !is_stripe_configured?
            subscriptions = nil
          end

          render_json_dump subscriptions
        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
      end

      def destroy
        params.require(:id)
        begin
          refund_subscription(params[:id]) if params[:refund]
          subscription = ::Stripe::Subscription.cancel(params[:id])

          customer =
            Customer.find_by(
              product_id: subscription[:plan][:product],
              customer_id: subscription[:customer],
            )

          if customer
            user = ::User.find(customer.user_id)
            group = plan_group(subscription[:plan])
            group.remove(user) if group
          end

          render_json_dump subscription
        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
      end

      private

      def get_subscriptions(start)
        ::Stripe::Subscription.list(
          expand: ["data.plan.product"],
          limit: PAGE_LIMIT,
          starting_after: start,
          status: "all",
        )
      end

      def find_valid_subscriptions(data, ids)
        valid = data.select { |sub| ids.include?(sub[:id]) }
        valid.empty? ? nil : valid
      end

      # this will only refund the most recent subscription payment
      def refund_subscription(subscription_id)
        subscription = ::Stripe::Subscription.retrieve(subscription_id)
        invoice = ::Stripe::Invoice.retrieve(subscription[:latest_invoice]) if subscription[
          :latest_invoice
        ]
        payment_intent = invoice[:payment_intent] if invoice[:payment_intent]
        refund = ::Stripe::Refund.create({ payment_intent: payment_intent })
      end
    end
  end
end
