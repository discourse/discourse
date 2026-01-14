# frozen_string_literal: true

require "stripe"
require "highline/import"

desc "Import subscriptions from Stripe"
task "subscriptions:subscriptions_import" => :environment do
  setup_api
  products = get_stripe_products
  strip_products_to_import = []

  procourse_import = false
  procourse_import_response =
    ask("Were the subscriptions you are importing created in Procourse Memberships?: (y/N)")
  procourse_import = true if procourse_import_response.downcase == "y"

  products.each do |product|
    confirm_import =
      ask("Do you wish to import product #{product[:name]} (id: #{product[:id]}): (y/N)")
    next if confirm_import.downcase != "y"
    strip_products_to_import << product
  end

  import_products(strip_products_to_import)
  import_subscriptions(procourse_import)
end

def get_stripe_products(starting_after: nil)
  puts "Getting products from Stripe API"

  all_products = []

  loop do
    products =
      Stripe::Product.list({ type: "service", starting_after: starting_after, active: true })
    all_products += products[:data]
    break if products[:has_more] == false
    starting_after = products[:data].last["id"]
  end

  all_products
end

def get_stripe_subscriptions(starting_after: nil)
  puts "Getting Subscriptions from Stripe API"

  all_subscriptions = []

  loop do
    subscriptions = Stripe::Subscription.list({ starting_after: starting_after, status: "active" })
    all_subscriptions += subscriptions[:data]
    break if subscriptions[:has_more] == false
    starting_after = subscriptions[:data].last["id"]
  end

  all_subscriptions
end

def get_stripe_customers(starting_after: nil)
  puts "Getting Customers from Stripe API"

  all_customers = []

  loop do
    customers = Stripe::Customer.list({ starting_after: starting_after })
    all_customers += customers[:data]
    break if customers[:has_more] == false
    starting_after = customers[:data].last["id"]
  end

  all_customers
end

def import_products(products)
  puts "Importing products:"

  products.each do |product|
    puts "Looking for external_id #{product[:id]} ..."
    if DiscourseSubscriptions::Product.find_by(external_id: product[:id]).blank?
      DiscourseSubscriptions::Product.create(external_id: product[:id])
      puts "Subscriptions Product external_id: #{product[:id]} CREATED"
    else
      puts "Subscriptions Product external_id: #{product[:id]} already exists"
    end
  end
end

def import_subscriptions(procourse_import)
  puts "Importing subscriptions"
  product_ids = DiscourseSubscriptions::Product.all.pluck(:external_id)

  all_customers = get_stripe_customers
  puts "Total available Stripe Customers: #{all_customers.length}, the first of which is customer id: #{all_customers[0][:description]}"

  subscriptions = get_stripe_subscriptions
  puts "Total Active Subscriptions available: #{subscriptions.length}"

  subscriptions_for_products =
    subscriptions.select { |sub| product_ids.include?(sub[:items][:data][0][:price][:product]) }
  puts "Total Subscriptions matching Products to Import: #{subscriptions_for_products.length}"

  subscriptions_for_products.each do |subscription|
    product_id = subscription[:items][:data][0][:plan][:product]
    customer_id = subscription[:customer]
    subscription_id = subscription[:id]

    if procourse_import
      stripe_customer = all_customers.select { |cust| cust[:id] == customer_id }
      user_id = stripe_customer[0][:description].to_i
      username = nil
    else
      user_id = subscription[:metadata][:user_id].to_i
      username = subscription[:metadata][:username]
    end

    if product_id && customer_id && subscription_id
      subscriptions_customer =
        DiscourseSubscriptions::Customer.find_by(
          user_id: user_id,
          customer_id: customer_id,
          product_id: product_id,
        )

      if subscriptions_customer.nil? && user_id && user_id > 0
        # create the customer record if doesn't exist only if the user_id and username match, which
        # prevents issues if multiple sites use the same Stripe account. Does not apply to a Procourse import.
        user = User.find(user_id)
        if procourse_import || (user && (user.username == username))
          subscriptions_customer =
            DiscourseSubscriptions::Customer.create(
              user_id: user_id,
              customer_id: customer_id,
              product_id: product_id,
            )
          puts "Subscriptions Customer user_id: #{user_id}, customer_id: #{customer_id}, product_id: #{product_id}) CREATED"
        end
      else
        puts "Subscriptions Customer user_id: #{user_id}, customer_id: #{customer_id}, product_id: #{product_id}) already exists"
      end

      if subscriptions_customer
        if DiscourseSubscriptions::Subscription.find_by(
             customer_id: subscriptions_customer.id,
             external_id: subscription_id,
           ).blank?
          DiscourseSubscriptions::Subscription.create(
            customer_id: subscriptions_customer.id,
            external_id: subscription_id,
          )
          puts "Discourse Subscription customer_id: #{subscriptions_customer.id}, external_id: #{subscription_id}) CREATED"
        else
          puts "Discourse Subscription customer_id: #{subscriptions_customer.id}, external_id: #{subscription_id}) already exists"
        end

        if procourse_import
          # Update Procourse Stripe data as it would be if it were created by discourse_subscriptions
          discourse_user = User.find(user_id)
          puts "Discourse User: #{discourse_user.username_lower} found for Strip metadata update ..."

          updated_subscription =
            Stripe::Subscription.update(
              subscription_id,
              { metadata: { user_id: user_id, username: discourse_user.username_lower } },
            )
          puts "Stripe Subscription: #{updated_subscription[:id]}, metadata: #{updated_subscription[:metadata]} UPDATED"

          updated_customer = Stripe::Customer.update(customer_id, { email: discourse_user.email })
          puts "Stripe Customer: #{updated_customer[:id]}, email: #{updated_customer[:email]} UPDATED"
        end
      end
    end
  end
end

private

def setup_api
  api_key = SiteSetting.discourse_subscriptions_secret_key || ask("Input Stripe secret key")
  Stripe.api_key = api_key
end
