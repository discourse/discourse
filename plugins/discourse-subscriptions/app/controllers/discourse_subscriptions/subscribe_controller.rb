# frozen_string_literal: true

module DiscourseSubscriptions
  class SubscribeController < ::ApplicationController
    include DiscourseSubscriptions::Stripe
    include DiscourseSubscriptions::Group

    requires_plugin DiscourseSubscriptions::PLUGIN_NAME

    before_action :set_api_key
    requires_login except: %i[index contributors show]

    def index
      begin
        product_ids = Product.all.pluck(:external_id)
        products = []

        if product_ids.present? && is_stripe_configured?
          response = ::Stripe::Product.list({ ids: product_ids, active: true })

          products = response[:data].map { |p| serialize_product(p) }
        end

        render_json_dump products
      rescue ::Stripe::InvalidRequestError => e
        render_json_error e.message
      end
    end

    def contributors
      return unless SiteSetting.discourse_subscriptions_campaign_show_contributors
      contributor_ids = Set.new

      campaign_product = SiteSetting.discourse_subscriptions_campaign_product
      if campaign_product.present?
        contributor_ids.merge(Customer.where(product_id: campaign_product).last(5).pluck(:user_id))
      else
        contributor_ids.merge(Customer.last(5).pluck(:user_id))
      end

      contributors = ::User.where(id: contributor_ids)

      render_serialized(contributors, UserSerializer)
    end

    def show
      params.require(:id)
      begin
        product = ::Stripe::Product.retrieve(params[:id])
        plans = ::Stripe::Price.list(active: true, product: params[:id])

        response = { product: serialize_product(product), plans: serialize_plans(plans) }

        render_json_dump response
      rescue ::Stripe::InvalidRequestError => e
        render_json_error e.message
      end
    end

    def create
      params.require(%i[source plan])
      begin
        customer =
          find_or_create_customer(
            params[:source],
            params[:cardholder_name],
            params[:cardholder_address],
          )
        plan = ::Stripe::Price.retrieve(params[:plan])

        if params[:promo].present?
          promo_code = ::Stripe::PromotionCode.list({ code: params[:promo] })
          promo_code = promo_code[:data][0] # we assume promo codes have a unique name

          if promo_code.blank?
            return render_json_error I18n.t("js.discourse_subscriptions.subscribe.invalid_coupon")
          end
        end

        recurring_plan = plan[:type] == "recurring"

        if recurring_plan
          trial_days = plan[:metadata][:trial_period_days] if plan[:metadata] &&
            plan[:metadata][:trial_period_days]

          promo_code_id = promo_code[:id] if promo_code

          subscription_params = {
            customer: customer[:id],
            items: [{ price: params[:plan] }],
            metadata: metadata_user,
            trial_period_days: trial_days,
            promotion_code: promo_code_id,
          }

          if SiteSetting.discourse_subscriptions_enable_automatic_tax
            subscription_params[:automatic_tax] = { enabled: true }
          end

          transaction = ::Stripe::Subscription.create(subscription_params)

          payment_intent = retrieve_payment_intent(transaction[:latest_invoice]) if transaction[
            :status
          ] == "incomplete"
        else
          coupon_id = promo_code[:coupon][:id] if promo_code && promo_code[:coupon] &&
            promo_code[:coupon][:id]

          invoice_params = { customer: customer[:id] }
          if SiteSetting.discourse_subscriptions_enable_automatic_tax
            invoice_params[:automatic_tax] = { enabled: true }
          end
          invoice = ::Stripe::Invoice.create(invoice_params)

          invoice_item =
            ::Stripe::InvoiceItem.create(
              customer: customer[:id],
              price: params[:plan],
              discounts: [{ coupon: coupon_id }],
              invoice: invoice[:id],
            )
          transaction = ::Stripe::Invoice.finalize_invoice(invoice[:id])
          payment_intent = retrieve_payment_intent(transaction[:id]) if transaction[:status] ==
            "open"
          if payment_intent.nil?
            return(
              render_json_error I18n.t("js.discourse_subscriptions.subscribe.transaction_error")
            )
          end
          transaction = ::Stripe::Invoice.pay(invoice[:id]) if payment_intent[:status] ==
            "successful"
        end

        finalize_transaction(transaction, plan) if transaction_ok(transaction)

        transaction = transaction.to_h.merge(transaction, payment_intent: payment_intent)

        render_json_dump transaction
      rescue ::Stripe::InvalidRequestError => e
        render_json_error e.message
      end
    end

    def finalize
      params.require(%i[plan transaction])
      begin
        price = ::Stripe::Price.retrieve(params[:plan])
        transaction = retrieve_transaction(params[:transaction])
        finalize_transaction(transaction, price) if transaction_ok(transaction)

        render_json_dump params[:transaction]
      rescue ::Stripe::InvalidRequestError => e
        render_json_error e.message
      end
    end

    def finalize_transaction(transaction, plan)
      group = plan_group(plan)

      group.add(current_user) if group

      customer =
        Customer.create(
          user_id: current_user.id,
          customer_id: transaction[:customer],
          product_id: plan[:product],
        )

      if transaction[:object] == "subscription"
        Subscription.create(
          customer_id: customer.id,
          external_id: transaction[:id],
          status: transaction[:status],
        )
      end
    end

    private

    def serialize_product(product)
      {
        id: product[:id],
        name: product[:name],
        description: PrettyText.cook(product[:metadata][:description]),
        subscribed: current_user_products.include?(product[:id]),
        repurchaseable: product[:metadata][:repurchaseable],
      }
    end

    def current_user_products
      return [] if current_user.nil?

      Customer
        .joins(:subscriptions)
        .where(user_id: current_user.id)
        .where(
          Subscription.arel_table[:status].eq(nil).or(
            Subscription.arel_table[:status].not_eq("canceled"),
          ),
        )
        .select(:product_id)
        .distinct
        .pluck(:product_id)
    end

    def serialize_plans(plans)
      plans[:data]
        .map { |plan| plan.to_h.slice(:id, :unit_amount, :currency, :type, :recurring) }
        .sort_by { |plan| plan[:amount] }
    end

    def find_or_create_customer(source, cardholder_name = nil, cardholder_address = nil)
      customer = Customer.find_by_user_id(current_user.id)
      cardholder_address =
        (
          if cardholder_address.present?
            {
              line1: cardholder_address[:line1],
              city: cardholder_address[:city],
              state: cardholder_address[:state],
              country: cardholder_address[:country],
              postal_code: cardholder_address[:postalCode],
            }
          else
            nil
          end
        )

      if customer.present?
        ::Stripe::Customer.retrieve(customer.customer_id)
      else
        ::Stripe::Customer.create(
          email: current_user.email,
          source: source,
          name: cardholder_name,
          address: cardholder_address,
        )
      end
    end

    def retrieve_payment_intent(invoice_id)
      invoice = ::Stripe::Invoice.retrieve(invoice_id)
      ::Stripe::PaymentIntent.retrieve(invoice[:payment_intent])
    end

    def retrieve_transaction(transaction)
      begin
        case transaction
        when /^sub_/
          ::Stripe::Subscription.retrieve(transaction)
        when /^in_/
          ::Stripe::Invoice.retrieve(transaction)
        end
      rescue ::Stripe::InvalidRequestError => e
        e.message
      end
    end

    def metadata_user
      { user_id: current_user.id, username: current_user.username_lower }
    end

    def transaction_ok(transaction)
      %w[active trialing paid].include?(transaction[:status])
    end
  end
end
