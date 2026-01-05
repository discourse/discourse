# frozen_string_literal: true

# TangyZen Deals Controller
# Handles deal submissions and display

module Tangyzen
  class DealsController < ::ApplicationController
    requires_plugin 'tangyzen'

    before_action :ensure_logged_in, only: [:create, :update, :destroy]
    before_action :fetch_deal, only: [:show, :update, :destroy]

    # GET /tangyzen/deals - List deals
    def index
      deals = Tangyzen::Deal.includes(:post, :category)
                  .active
                  .filter(params)
                  .order(params)
                  .page(params[:page])
      
      render_json_serialize(deals, root: 'deals', each_serializer: Tangyzen::DealSerializer)
    end

    # GET /tangyzen/deals/:id - Show deal
    def show
      render_json_serialize(@deal, serializer: Tangyzen::DealSerializer)
    end

    # POST /tangyzen/deals - Create deal
    def create
      @deal = Tangyzen::Deal.new(deal_params)
      @deal.user = current_user

      if @deal.save
        create_discourse_post(@deal)
        enqueue_notifications(@deal)
        render_json_serialize(@deal, serializer: Tangyzen::DealSerializer, status: 201)
      else
        render_json_error(@deal.errors.full_messages, status: 422)
      end
    end

    # PUT /tangyzen/deals/:id - Update deal
    def update
      return render_json_error("Not authorized", status: 403) unless can_edit?(@deal)

      if @deal.update(deal_params)
        render_json_serialize(@deal, serializer: Tangyzen::DealSerializer)
      else
        render_json_error(@deal.errors.full_messages, status: 422)
      end
    end

    # DELETE /tangyzen/deals/:id - Destroy deal
    def destroy
      return render_json_error("Not authorized", status: 403) unless can_edit?(@deal)

      @deal.destroy
      render json: success_json
    end

    # GET /tangyzen/deals/featured - Featured deals
    def featured
      deals = Tangyzen::Deal.includes(:post, :category)
                  .featured
                  .active
                  .limit(SiteSetting.tangyzen_featured_count || 10)
      
      render_json_serialize(deals, root: 'deals', each_serializer: Tangyzen::DealSerializer)
    end

    # GET /tangyzen/deals/trending - Trending deals
    def trending
      deals = Tangyzen::Deal.includes(:post, :category)
                  .trending
                  .active
                  .limit(SiteSetting.tangyzen_trending_count || 20)
      
      render_json_serialize(deals, root: 'deals', each_serializer: Tangyzen::DealSerializer)
    end

    private

    def deal_params
      params.permit(
        :title,
        :body,
        :original_price,
        :current_price,
        :discount_percentage,
        :deal_url,
        :store_name,
        :coupon_code,
        :expiry_date,
        :category_id,
        :tag_names => [],
        :images => []
      )
    end

    def fetch_deal
      @deal = Tangyzen::Deal.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render_json_error("Deal not found", status: 404)
    end

    def can_edit?(deal)
      current_user.staff? || deal.user_id == current_user.id
    end

    def create_discourse_post(deal)
      PostCreator.create(
        current_user,
        raw: format_deal_post(deal),
        title: deal.title,
        category: deal.category_id,
        tags: deal.tag_names,
        archetype: Archetype.private_message
      )
    end

    def format_deal_post(deal)
      body = deal.body
      body += "\n\n---\n"
      body += "## Deal Details\n\n"
      body += "| | |\n"
      body += "|---|---|\n"
      body += "| Original Price | $#{deal.original_price} |\n"
      body += "| Current Price | $#{deal.current_price} |\n"
      body += "| Discount | **#{deal.discount_percentage}% off** |\n"
      body += "| Store | #{deal.store_name} |\n"
      
      if deal.coupon_code.present?
        body += "| Coupon Code | `#{deal.coupon_code}` |\n"
      end
      
      if deal.expiry_date.present?
        body += "| Expires | #{deal.expiry_date.strftime('%B %d, %Y')} |\n"
      end
      
      body += "\n[View Deal](#{deal.deal_url})"
      
      body
    end

    def enqueue_notifications(deal)
      Jobs.enqueue(:notify_followers, deal_id: deal.id, type: 'deal')
    end
  end
end
