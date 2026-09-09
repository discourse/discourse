# frozen_string_literal: true

module DiscourseSubscriptions
  module Admin
    class ProductsController < ::Admin::AdminController
      include DiscourseSubscriptions::Stripe

      requires_plugin PLUGIN_NAME

      def index
        product_ids = Product.all.pluck(:external_id)
        products = []

        if product_ids.present? && is_stripe_configured?
          products = stripe_client.v1.products.list({ ids: product_ids, limit: 100 })
          products = products[:data]
        elsif !is_stripe_configured?
          products = nil
        end

        render_json_dump products
      rescue ::Stripe::InvalidRequestError => e
        render_json_error e.message
      end

      def create
        create_params = product_params.merge!(type: "service")

        create_params.except!(:statement_descriptor) if params[:statement_descriptor].blank?

        product = stripe_client.v1.products.create(create_params)

        Product.create(external_id: product[:id])

        render_json_dump product
      rescue ::Stripe::InvalidRequestError => e
        render_json_error e.message
      end

      def show
        product = stripe_client.v1.products.retrieve(params[:id])

        render_json_dump product
      rescue ::Stripe::InvalidRequestError => e
        render_json_error e.message
      end

      def update
        product = stripe_client.v1.products.update(params[:id], product_params)

        render_json_dump product
      rescue ::Stripe::InvalidRequestError => e
        render_json_error e.message
      end

      def destroy
        product = stripe_client.v1.products.delete(params[:id], {})

        Product.delete_by(external_id: params[:id])

        render_json_dump product
      rescue ::Stripe::InvalidRequestError => e
        render_json_error e.message
      end

      private

      def product_params
        params.permit!

        {
          name: params[:name],
          active: params[:active],
          statement_descriptor: params[:statement_descriptor],
          metadata: {
            description: params.dig(:metadata, :description),
            repurchaseable: params.dig(:metadata, :repurchaseable),
          },
        }
      end
    end
  end
end
