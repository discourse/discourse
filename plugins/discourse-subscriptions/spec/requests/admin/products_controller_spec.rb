# frozen_string_literal: true

RSpec.describe DiscourseSubscriptions::Admin::ProductsController, :setup_stripe_mock do
  before { setup_discourse_subscriptions }

  it "is a subclass of AdminController" do
    expect(DiscourseSubscriptions::Admin::ProductsController < ::Admin::AdminController).to eq(true)
  end

  context "when unauthenticated" do
    it "does not list the products" do
      ::Stripe::Product.expects(:list).never
      get "/s/admin/products.json"
      expect(response.status).to eq(404)
    end

    it "does not create the product" do
      ::Stripe::Product.expects(:create).never
      post "/s/admin/products.json"
      expect(response.status).to eq(404)
    end

    it "does not show the product" do
      ::Stripe::Product.expects(:retrieve).never
      get "/s/admin/products/prod_qwerty123.json"
      expect(response.status).to eq(404)
    end

    it "does not update the product" do
      ::Stripe::Product.expects(:update).never
      put "/s/admin/products/prod_qwerty123.json"
      expect(response.status).to eq(404)
    end

    it "does not delete the product" do
      ::Stripe::Product.expects(:delete).never
      delete "/s/admin/products/u2.json"
      expect(response.status).to eq(404)
    end
  end

  context "when authenticated" do
    fab!(:admin)

    before { sign_in(admin) }

    describe "index" do
      it "gets the empty products" do
        SiteSetting.discourse_subscriptions_public_key = "public-key"
        get "/s/admin/products.json"
        expect(response.parsed_body).to be_empty
      end

      it "lists products from Stripe" do
        SiteSetting.discourse_subscriptions_public_key = "public-key"
        stripe_product = ::Stripe::Product.create(name: "Test Product", type: "service")
        Fabricate(:product, external_id: stripe_product.id)

        get "/s/admin/products.json"
        expect(response.status).to eq(200)

        body = response.parsed_body
        expect(body.length).to eq(1)
        expect(body[0]["id"]).to eq(stripe_product.id)
        expect(body[0]["name"]).to eq("Test Product")
      end
    end

    describe "create" do
      it "creates a product with all attributes" do
        post "/s/admin/products.json",
             params: {
               name: "Test Product",
               active: "true",
               statement_descriptor: "TESTPRODUCT",
               metadata: {
                 description: "A test product description",
                 repurchaseable: "false",
               },
             }
        expect(response.status).to eq(200)

        body = response.parsed_body
        expect(body["name"]).to eq("Test Product")
        expect(body["active"]).to be_truthy
        expect(body["statement_descriptor"]).to eq("TESTPRODUCT")
        expect(body.dig("metadata", "description")).to eq("A test product description")
        expect(body.dig("metadata", "repurchaseable")).to eq("false")
      end

      it "has no statement descriptor if empty" do
        ::Stripe::Product.expects(:create).with(has_key(:statement_descriptor)).never
        post "/s/admin/products.json", params: { statement_descriptor: "" }
      end
    end

    describe "show" do
      it "retrieves the product" do
        stripe_product = ::Stripe::Product.create(name: "Show Product", type: "service")
        Fabricate(:product, external_id: stripe_product.id)

        get "/s/admin/products/#{stripe_product.id}.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["name"]).to eq("Show Product")
      end
    end

    describe "update" do
      it "updates the product" do
        stripe_product = ::Stripe::Product.create(name: "Before Update", type: "service")
        Fabricate(:product, external_id: stripe_product.id)

        patch "/s/admin/products/#{stripe_product.id}.json", params: { name: "After Update" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["name"]).to eq("After Update")
      end
    end

    describe "delete" do
      it "deletes the product" do
        stripe_product = ::Stripe::Product.create(name: "Delete Me", type: "service")
        Fabricate(:product, external_id: stripe_product.id)

        delete "/s/admin/products/#{stripe_product.id}.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["deleted"]).to eq(true)
      end
    end
  end
end
