# frozen_string_literal: true

module DiscourseSubscriptions
  class HooksController < ::ApplicationController
    include DiscourseSubscriptions::Group
    include DiscourseSubscriptions::Stripe

    requires_plugin DiscourseSubscriptions::PLUGIN_NAME

    layout false

    before_action :set_api_key
    skip_before_action :check_xhr
    skip_before_action :redirect_to_login_if_required
    skip_before_action :verify_authenticity_token, only: [:create]

    def create
      begin
        payload = request.body.read
        sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
        webhook_secret = SiteSetting.discourse_subscriptions_webhook_secret

        event = ::Stripe::Webhook.construct_event(payload, sig_header, webhook_secret)
      rescue JSON::ParserError => e
        return render_json_error e.message
      rescue ::Stripe::SignatureVerificationError => e
        return render_json_error e.message
      end

      case event[:type]
      when "checkout.session.completed"
        checkout_session = event[:data][:object]

        if SiteSetting.discourse_subscriptions_enable_verbose_logging
          Rails.logger.warn("checkout.session.completed data: #{checkout_session}")
        end
        email = checkout_session[:customer_email]

        return head 200 if checkout_session[:status] != "complete"
        return render_json_error "email not found" if !email

        if checkout_session[:customer].nil?
          customer = ::Stripe::Customer.create({ email: email })
          customer_id = customer[:id]
        else
          customer_id = checkout_session[:customer]
        end

        if SiteSetting.discourse_subscriptions_enable_verbose_logging
          Rails.logger.warn("Looking up user with email: #{email}")
        end

        user = ::User.find_by_username_or_email(email)

        return render_json_error "user not found" if !user

        discourse_customer = Customer.create(user_id: user.id, customer_id: customer_id)

        subscription = checkout_session[:subscription]

        if subscription.present?
          Subscription.create(customer_id: discourse_customer.id, external_id: subscription)
        end

        line_items =
          ::Stripe::Checkout::Session.list_line_items(checkout_session[:id], { limit: 1 })
        item = line_items[:data].first

        group = plan_group(item[:price])
        group.add(user) unless group.nil?

        if SiteSetting.discourse_subscriptions_enable_verbose_logging
          Rails.logger.warn("Line item with group name meta data: #{item[:price]}")
          if group.nil?
            Rails.logger.warn("Group not found or not listed in metadata!")
          else
            Rails.logger.warn("Group: #{group.name}")
          end
        end

        discourse_customer.product_id = item[:price][:product]
        discourse_customer.save!

        if !subscription.nil?
          ::Stripe::Subscription.update(
            subscription,
            { metadata: { user_id: user.id, username: user.username } },
          )
        end
      when "customer.subscription.created"
      when "customer.subscription.updated"
        subscription = event[:data][:object]
        status = subscription[:status]
        return head 200 if !%w[complete active].include?(status)

        customer = find_active_customer(subscription[:customer], subscription[:plan][:product])

        return render_json_error "customer not found" if !customer

        update_status(customer.id, subscription[:id], status)

        user = ::User.find_by(id: customer.user_id)
        return render_json_error "user not found" if !user

        if group = plan_group(subscription[:plan])
          group.add(user)
        end
      when "customer.subscription.deleted"
        subscription = event[:data][:object]

        customer = find_active_customer(subscription[:customer], subscription[:plan][:product])

        return render_json_error "customer not found" if !customer

        update_status(customer.id, subscription[:id], subscription[:status])

        user = ::User.find(customer.user_id)
        return render_json_error "user not found" if !user

        if group = plan_group(subscription[:plan])
          group.remove(user)
        end
      end

      head 200
    end

    private

    def update_status(customer_id, subscription_id, status)
      discourse_subscription =
        Subscription.find_by(customer_id: customer_id, external_id: subscription_id)
      discourse_subscription.update(status: status) if discourse_subscription
    end

    def find_active_customer(customer_id, product_id)
      Customer
        .joins(:subscriptions)
        .where(customer_id: customer_id, product_id: product_id)
        .where(
          Subscription.arel_table[:status].eq(nil).or(
            Subscription.arel_table[:status].not_eq("canceled"),
          ),
        )
        .first
    end
  end
end
