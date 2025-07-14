# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseSubscriptions::Admin::ProductsController do
  before { SiteSetting.discourse_subscriptions_enabled = true }

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
    let(:admin) { Fabricate(:admin) }

    before { sign_in(admin) }

    describe "index" do
      it "gets the empty products" do
        SiteSetting.discourse_subscriptions_public_key = "public-key"
        SiteSetting.discourse_subscriptions_secret_key = "secret-key"
        get "/s/admin/products.json"
        expect(response.parsed_body).to be_empty
      end
    end

    describe "create" do
      it "is of product type service" do
        ::Stripe::Product.expects(:create).with(has_entry(:type, "service"))
        post "/s/admin/products.json", params: {}
      end

      it "has a name" do
        ::Stripe::Product.expects(:create).with(has_entry(:name, "Jesse Pinkman"))
        post "/s/admin/products.json", params: { name: "Jesse Pinkman" }
      end

      it "has an active attribute" do
        ::Stripe::Product.expects(:create).with(has_entry(active: "false"))
        post "/s/admin/products.json", params: { active: "false" }
      end

      it "has a statement descriptor" do
        ::Stripe::Product.expects(:create).with(
          has_entry(statement_descriptor: "Blessed are the cheesemakers"),
        )
        post "/s/admin/products.json",
             params: {
               statement_descriptor: "Blessed are the cheesemakers",
             }
      end

      it "has no statement descriptor if empty" do
        ::Stripe::Product.expects(:create).with(has_key(:statement_descriptor)).never
        post "/s/admin/products.json", params: { statement_descriptor: "" }
      end

      it "has metadata" do
        ::Stripe::Product.expects(:create).with(
          has_entry(
            metadata: {
              description: "Oi, I think he just said bless be all the bignoses!",
              repurchaseable: "false",
            },
          ),
        )

        post "/s/admin/products.json",
             params: {
               metadata: {
                 description: "Oi, I think he just said bless be all the bignoses!",
                 repurchaseable: "false",
               },
             }
      end
    end

    describe "show" do
      it "retrieves the product" do
        ::Stripe::Product.expects(:retrieve).with("prod_walterwhite")
        get "/s/admin/products/prod_walterwhite.json"
      end
    end

    describe "update" do
      it "updates the product" do
        ::Stripe::Product.expects(:update)
        patch "/s/admin/products/prod_walterwhite.json", params: {}
      end
    end

    describe "delete" do
      it "deletes the product" do
        ::Stripe::Product.expects(:delete).with("prod_walterwhite")
        delete "/s/admin/products/prod_walterwhite.json"
      end
    end
  end
end
