# frozen_string_literal: true

module DiscourseSubscriptions
  class Campaign
    include DiscourseSubscriptions::Stripe
    def initialize
      set_api_key # instantiates Stripe API
    end

    def refresh_data
      product_ids = Set.new(Product.all.pluck(:external_id))

      # if a product id is set for the campaign, we only want to return those results.
      # if it's blank, return them all.
      campaign_product = SiteSetting.discourse_subscriptions_campaign_product
      if campaign_product.present?
        product_ids = product_ids.include?(campaign_product) ? [campaign_product] : []
      end

      amount = 0.00
      subscriptions = get_subscription_data
      subscriptions = filter_to_subscriptions_products(subscriptions, product_ids)

      # Fetch product purchases
      one_time_payments = get_one_time_payments(product_ids)
      one_time_payments.each { |c| amount += c[:price].to_f / 100.00 }

      # get number of subscribers
      SiteSetting.discourse_subscriptions_campaign_subscribers = subscriptions&.length.to_i

      # calculate amount raised
      subscriptions&.each do |sub|
        sub_amount = calculate_monthly_amount(sub)
        amount += sub_amount / 100.00
      end

      SiteSetting.discourse_subscriptions_campaign_amount_raised = amount.round(2)

      check_goal_status
    end

    def create_campaign
      begin
        group = create_campaign_group
        product = create_campaign_product
        create_campaign_prices(product, group)

        SiteSetting.discourse_subscriptions_campaign_enabled = true
        SiteSetting.discourse_subscriptions_campaign_product = product[:id]
      rescue ::Stripe::InvalidRequestError => e
        e
      end
    end

    protected

    def goal_met_date_key
      "subscriptions_goal_met_date"
    end

    def check_goal_status
      goal = SiteSetting.discourse_subscriptions_campaign_goal
      goal_type = SiteSetting.discourse_subscriptions_campaign_type

      case goal_type
      when "Amount"
        current_volume = SiteSetting.discourse_subscriptions_campaign_amount_raised
      when "Subscribers"
        current_volume = SiteSetting.discourse_subscriptions_campaign_subscribers
      end

      goal_met_date = Discourse.redis.get(goal_met_date_key)

      if goal_met_date
        # delete the key if we're at or below 90% of the goal
        Discourse.redis.del(goal_met_date_key) if current_volume / goal <= 0.90
      else
        Discourse.redis.set(goal_met_date_key, Time.now) if current_volume > goal
      end
    end

    def create_campaign_group
      campaign_group = SiteSetting.discourse_subscriptions_campaign_group
      group = ::Group.find_by_id(campaign_group) if campaign_group.present?

      unless group
        group = ::Group.create(name: "campaign_supporters")

        SiteSetting.discourse_subscriptions_campaign_group = group[:id]

        params = {
          full_name: I18n.t("js.discourse_subscriptions.campaign.supporters"),
          title: I18n.t("js.discourse_subscriptions.campaign.supporter"),
          flair_icon: "circle-dollar-to-slot",
        }

        group.update(params)
      end

      group[:name]
    end

    def create_campaign_product
      product_params = {
        name: I18n.t("js.discourse_subscriptions.campaign.title"),
        active: true,
        metadata: {
          description: I18n.t("js.discourse_subscriptions.campaign.body"),
        },
      }

      product = ::Stripe::Product.create(product_params)

      Product.create(external_id: product[:id])

      product
    end

    def create_campaign_prices(product, group)
      # hard coded defaults to make setting this up as simple as possible
      monthly_prices = [3, 5, 10, 25]
      yearly_prices = [50, 100]

      monthly_prices.each { |price| create_price(product[:id], group, price, "month") }

      yearly_prices.each { |price| create_price(product[:id], group, price, "year") }
    end

    def create_price(product_id, group_name, amount, recurrence)
      price_object = {
        nickname: "#{amount}/#{recurrence}",
        unit_amount: amount * 100,
        product: product_id,
        currency: SiteSetting.discourse_subscriptions_currency,
        active: true,
        recurring: {
          interval: recurrence,
        },
        metadata: {
          group_name: group_name,
        },
      }

      plan = ::Stripe::Price.create(price_object)
    end

    def get_one_time_payments(product_ids)
      one_time_payments = []
      current_set = { has_more: true, last_record: nil }

      if product_ids.present?
        # lots of matching because the Stripe API doesn't make it easy to match products => payments except from invoices
        until current_set[:has_more] == false
          all_invoices =
            ::Stripe::Invoice.list(limit: 100, starting_after: current_set[:last_record])

          if all_invoices[:data].present?
            current_set[:last_record] = all_invoices[:data].last[:id]
            current_set[:has_more] = all_invoices[:has_more]

            all_invoices[:data].each do |invoice|
              customer_id = invoice[:customer]
              next if invoice[:paid] != true
              line_item = invoice[:lines][:data][0] if invoice[:lines] && invoice[:lines][:data] # Discourse only makes single-line item charges
              # check if non-subscription and that the plan is active
              if line_item && line_item[:plan] == nil && line_item[:price] &&
                   line_item[:price][:recurring] == nil && line_item[:price][:active] == true
                product_id = line_item[:price][:product]
                if product_ids.include? product_id
                  line_data = {
                    customer_id: customer_id,
                    product_id: product_id,
                    price: line_item[:price][:unit_amount],
                  }
                  one_time_payments << line_data
                end
              end
            end
          else
            current_set[:has_more] = false
          end
        end
      end

      one_time_payments
    end

    def get_subscription_data
      subscriptions = []
      current_set = { has_more: true, last_record: nil }

      until current_set[:has_more] == false
        current_set =
          ::Stripe::Subscription.list(
            expand: ["data.plan.product"],
            limit: 100,
            starting_after: current_set[:last_record],
          )

        current_set[:last_record] = current_set[:data].last[:id] if current_set[:data].present?
        subscriptions.concat(current_set[:data].to_a)
      end

      subscriptions
    end

    def filter_to_subscriptions_products(data, ids)
      valid =
        data.select do |sub|
          # cannot .dig stripe objects
          items = sub[:items][:data][0] if sub[:items] && sub[:items][:data]
          product = items[:price][:product] if items[:price] && items[:price][:product]

          ids.include?(product)
        end
      valid.empty? ? nil : valid
    end

    def calculate_monthly_amount(sub)
      items = sub[:items][:data][0] if sub[:items] && sub[:items][:data]
      price = items[:price] if items[:price]
      unit_amount = price[:unit_amount] if price[:unit_amount]
      recurrence = price[:recurring][:interval] if price[:recurring] && price[:recurring][:interval]

      case recurrence
      when "day"
        unit_amount = unit_amount * 30
      when "week"
        unit_amount = unit_amount * 4
      when "year"
        unit_amount = unit_amount / 12.00
      end

      unit_amount.to_f
    end
  end
end
