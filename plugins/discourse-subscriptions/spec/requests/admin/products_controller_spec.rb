# frozen_string_literal: true

RSpec.describe DiscourseSubscriptions::Admin::ProductsController do
  fab!(:admin)

  before do
    SiteSetting.discourse_subscriptions_enabled = true
    SiteSetting.discourse_subscriptions_secret_key = "sk_test_fictional_products"
    SiteSetting.discourse_subscriptions_public_key = "pk_test_fictional_products"
  end

  let(:stripe_headers) do
    { "Authorization" => "Bearer sk_test_fictional_products", "Stripe-Version" => "2024-04-10" }
  end
  let(:product_response) do
    {
      status: 200,
      body: { id: "prod_fictional", object: "product", name: "Support the community" }.to_json,
      headers: {
        "Content-Type" => "application/json",
      },
    }
  end

  describe "#index" do
    it "requires an administrator" do
      get "/s/admin/products.json"

      expect(response.status).to eq(404)
    end

    it "returns published products using the current site's credentials" do
      Fabricate(:product, external_id: "prod_fictional")
      sign_in(admin)
      request =
        stub_request(:get, "https://api.stripe.com/v1/products").with(
          headers: stripe_headers,
          query: {
            "ids" => ["prod_fictional"],
            "limit" => "100",
          },
        ).to_return(
          status: 200,
          body: { object: "list", data: [{ id: "prod_fictional", object: "product" }] }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        )

      get "/s/admin/products.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.pluck("id")).to eq(["prod_fictional"])
      expect(request).to have_been_requested
    end

    it "returns an empty list without published products" do
      sign_in(admin)

      get "/s/admin/products.json"

      expect(response.parsed_body).to eq([])
    end
  end

  describe "#create" do
    it "requires an administrator" do
      post "/s/admin/products.json"

      expect(response.status).to eq(404)
    end

    it "creates a service product with its name, status, descriptor, and metadata" do
      sign_in(admin)
      request =
        stub_request(:post, "https://api.stripe.com/v1/products").with(
          headers: stripe_headers,
          body: {
            "type" => "service",
            "name" => "Support the community",
            "active" => "false",
            "statement_descriptor" => "COMMUNITY",
            "metadata" => {
              "description" => "Monthly support",
              "repurchaseable" => "false",
            },
          },
        ).to_return(product_response)

      post "/s/admin/products.json",
           params: {
             name: "Support the community",
             active: false,
             statement_descriptor: "COMMUNITY",
             metadata: {
               description: "Monthly support",
               repurchaseable: false,
             },
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["id"]).to eq("prod_fictional")
      expect(DiscourseSubscriptions::Product.exists?(external_id: "prod_fictional")).to eq(true)
      expect(request).to have_been_requested
    end

    it "omits an empty statement descriptor" do
      sign_in(admin)
      request =
        stub_request(:post, "https://api.stripe.com/v1/products")
          .with do |stripe_request|
            !Rack::Utils.parse_nested_query(stripe_request.body).key?("statement_descriptor")
          end
          .to_return(product_response)

      post "/s/admin/products.json", params: { name: "Support", statement_descriptor: "" }

      expect(response.status).to eq(200)
      expect(request).to have_been_requested
    end
  end

  describe "#show" do
    it "requires an administrator" do
      get "/s/admin/products/prod_fictional.json"

      expect(response.status).to eq(404)
    end

    it "uses a newly configured key on the next request" do
      sign_in(admin)
      first_request =
        stub_request(:get, "https://api.stripe.com/v1/products/prod_fictional").with(
          headers: stripe_headers,
        ).to_return(product_response)
      second_request =
        stub_request(:get, "https://api.stripe.com/v1/products/prod_fictional").with(
          headers: stripe_headers.merge("Authorization" => "Bearer sk_test_fictional_replacement"),
        ).to_return(product_response)

      get "/s/admin/products/prod_fictional.json"
      expect(response.status).to eq(200)
      SiteSetting.discourse_subscriptions_secret_key = "sk_test_fictional_replacement"
      get "/s/admin/products/prod_fictional.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["id"]).to eq("prod_fictional")
      expect(first_request).to have_been_requested.once
      expect(second_request).to have_been_requested.once
    end
  end

  describe "#update" do
    it "requires an administrator" do
      patch "/s/admin/products/prod_fictional.json"

      expect(response.status).to eq(404)
    end

    it "updates the product" do
      sign_in(admin)
      request =
        stub_request(:post, "https://api.stripe.com/v1/products/prod_fictional").with(
          headers: stripe_headers,
          body: hash_including("name" => "Support the community"),
        ).to_return(product_response)

      patch "/s/admin/products/prod_fictional.json", params: { name: "Support the community" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["name"]).to eq("Support the community")
      expect(request).to have_been_requested
    end
  end

  describe "#destroy" do
    it "requires an administrator" do
      delete "/s/admin/products/prod_fictional.json"

      expect(response.status).to eq(404)
    end

    it "deletes the product remotely and locally" do
      Fabricate(:product, external_id: "prod_fictional")
      sign_in(admin)
      request =
        stub_request(:delete, "https://api.stripe.com/v1/products/prod_fictional").with(
          headers: stripe_headers,
        ).to_return(product_response)

      delete "/s/admin/products/prod_fictional.json"

      expect(response.status).to eq(200)
      expect(DiscourseSubscriptions::Product.exists?(external_id: "prod_fictional")).to eq(false)
      expect(request).to have_been_requested
    end
  end
end
