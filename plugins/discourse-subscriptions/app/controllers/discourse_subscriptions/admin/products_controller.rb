# frozen_string_literal: true

module DiscourseSubscriptions
  module Admin
    class ProductsController < ::Admin::AdminController
      include DiscourseSubscriptions::Stripe

      requires_plugin DiscourseSubscriptions::PLUGIN_NAME

      before_action :set_api_key

      def index
        begin
          product_ids = Product.all.pluck(:external_id)
          products = []

          if product_ids.present? && is_stripe_configured?
            products = ::Stripe::Product.list({ ids: product_ids, limit: 100 })
            products = products[:data]
          elsif !is_stripe_configured?
            products = nil
          end

          render_json_dump products
        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
      end

      def create
        begin
          create_params = product_params.merge!(type: "service")

          create_params.except!(:statement_descriptor) if params[:statement_descriptor].blank?

          product = ::Stripe::Product.create(create_params)

          Product.create(external_id: product[:id])

          render_json_dump product
        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
      end

      def show
        begin
          product = ::Stripe::Product.retrieve(params[:id])

          render_json_dump product
        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
      end

      def update
        begin
          product = ::Stripe::Product.update(params[:id], product_params)

          render_json_dump product
        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
      end

      def destroy
        begin
          product = ::Stripe::Product.delete(params[:id])

          Product.delete_by(external_id: params[:id])

          render_json_dump product
        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
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
