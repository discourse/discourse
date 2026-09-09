# frozen_string_literal: true

RSpec.describe DiscourseSubscriptions::Stripe do
  describe ".client" do
    it "binds credentials and API version to each client across interleaved requests" do
      original_key = ::Stripe.api_key
      original_version = ::Stripe.api_version
      SiteSetting.discourse_subscriptions_secret_key = "sk_test_fictional_first"
      first_client = described_class.client
      SiteSetting.discourse_subscriptions_secret_key = "sk_test_fictional_second"
      second_client = described_class.client
      requests = []
      stub_request(:get, "https://api.stripe.com/v1/products/prod_fictional").to_return do |request|
        requests << request.headers.slice("Authorization", "Stripe-Version")
        {
          status: 200,
          body: { id: "prod_fictional", object: "product" }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        }
      end

      first_client.v1.products.retrieve("prod_fictional")
      second_client.v1.products.retrieve("prod_fictional")
      first_client.v1.products.retrieve("prod_fictional")

      expect(requests).to eq(
        %w[sk_test_fictional_first sk_test_fictional_second sk_test_fictional_first].map do |key|
          { "Authorization" => "Bearer #{key}", "Stripe-Version" => "2024-04-10" }
        end,
      )
      expect(::Stripe.api_key).to eq(original_key)
      expect(::Stripe.api_version).to eq(original_version)
    end

    it "uses an explicitly supplied import key" do
      SiteSetting.discourse_subscriptions_secret_key = "sk_test_fictional_site"
      request =
        stub_request(:get, "https://api.stripe.com/v1/products").with(
          headers: {
            "Authorization" => "Bearer sk_test_fictional_import",
            "Stripe-Version" => "2024-04-10",
          },
        ).to_return(
          status: 200,
          body: { object: "list", data: [], has_more: false }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        )

      result = described_class.client(api_key: "sk_test_fictional_import").v1.products.list

      expect(result.data).to eq([])
      expect(request).to have_been_requested
    end

    it "rejects missing credentials even when Stripe has a global key" do
      ::Stripe.stubs(:api_key).returns("sk_test_fictional_global")
      SiteSetting.discourse_subscriptions_secret_key = ""

      expect { described_class.client }.to raise_error(
        ::Stripe::AuthenticationError,
        "Stripe secret key is not configured",
      )
      [nil, "", " "].each do |key|
        expect { described_class.client(api_key: key) }.to raise_error(
          ::Stripe::AuthenticationError,
        )
      end
    end
  end
end
