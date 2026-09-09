# frozen_string_literal: true

require "highline/import"

RSpec.describe "subscriptions:subscriptions_import" do
  fab!(:user)

  describe "invoke" do
    before do
      HighLine.stubs(:ask).returns("y")
      stub_request(:get, "https://api.stripe.com/v1/products").with(
        query: {
          "type" => "service",
          "active" => "true",
        },
      ).to_return(
        status: 200,
        body: {
          object: "list",
          data: [{ id: "prod_fictional", object: "product", name: "Community support" }],
          has_more: false,
        }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )
      stub_request(:get, "https://api.stripe.com/v1/customers").to_return(
        status: 200,
        body: {
          object: "list",
          data: [{ id: "cus_fictional", object: "customer", description: user.id.to_s }],
          has_more: false,
        }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )
      stub_request(:get, "https://api.stripe.com/v1/subscriptions").with(
        query: {
          "status" => "active",
        },
      ).to_return(
        status: 200,
        body: {
          object: "list",
          data: [
            {
              id: "sub_fictional",
              object: "subscription",
              customer: "cus_fictional",
              items: {
                data: [
                  { price: { product: "prod_fictional" }, plan: { product: "prod_fictional" } },
                ],
              },
            },
          ],
          has_more: false,
        }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )
      stub_request(:post, "https://api.stripe.com/v1/subscriptions/sub_fictional").with(
        body: {
          "metadata" => {
            "user_id" => user.id.to_s,
            "username" => user.username_lower,
          },
        },
      ).to_return(
        status: 200,
        body: { id: "sub_fictional", object: "subscription", metadata: {} }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )
      stub_request(:post, "https://api.stripe.com/v1/customers/cus_fictional").with(
        body: {
          "email" => user.email,
        },
      ).to_return(
        status: 200,
        body: { id: "cus_fictional", object: "customer", email: user.email }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )
    end

    it "uses the configured key for every import request without changing global credentials" do
      SiteSetting.discourse_subscriptions_secret_key = "sk_test_fictional_import"
      original_key = ::Stripe.api_key
      original_version = ::Stripe.api_version

      capture_stdout { invoke_rake_task("subscriptions:subscriptions_import") }

      expect(DiscourseSubscriptions::Product.exists?(external_id: "prod_fictional")).to eq(true)
      expect(DiscourseSubscriptions::Customer.find_by(customer_id: "cus_fictional").user_id).to eq(
        user.id,
      )
      expect(DiscourseSubscriptions::Subscription.exists?(external_id: "sub_fictional")).to eq(true)
      expect(
        a_request(:any, %r{\Ahttps://api\.stripe\.com/v1/}).with(
          headers: {
            "Authorization" => "Bearer sk_test_fictional_import",
            "Stripe-Version" => "2024-04-10",
          },
        ),
      ).to have_been_made.times(5)
      expect(::Stripe.api_key).to eq(original_key)
      expect(::Stripe.api_version).to eq(original_version)
    end

    it "uses the prompted key when the site key is blank" do
      SiteSetting.discourse_subscriptions_secret_key = ""
      HighLine.stubs(:ask).with("Input Stripe secret key").returns("sk_test_fictional_prompt")

      capture_stdout { invoke_rake_task("subscriptions:subscriptions_import") }

      expect(
        a_request(:any, %r{\Ahttps://api\.stripe\.com/v1/}).with(
          headers: {
            "Authorization" => "Bearer sk_test_fictional_prompt",
            "Stripe-Version" => "2024-04-10",
          },
        ),
      ).to have_been_made.times(5)
      expect(SiteSetting.discourse_subscriptions_secret_key).to eq("")
    end
  end
end
