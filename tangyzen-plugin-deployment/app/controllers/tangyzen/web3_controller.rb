# frozen_string_literal: true

module Tangyzen
  class Web3Controller < ::ApplicationController
    requires_plugin ::TangyzenPlugin.enabled

    before_action :ensure_logged_in, only: [:connect_wallet, :disconnect_wallet]

    # GET /tangyzen/web3/nfts.json
    def nfts
      collection_slug = params[:collection]
      wallet_address = params[:wallet]
      limit = (params[:limit] || 20).to_i.clamp(1, 100)
      offset = (params[:offset] || 0).to_i.clamp(0, 10000)

      client = OpenSeaClient.new

      begin
        if wallet_address.present?
          nfts_data = client.get_user_nfts(wallet_address: wallet_address, limit: limit, offset: offset)
        elsif collection_slug.present?
          nfts_data = client.get_nfts(collection_slug: collection_slug, limit: limit, offset: offset)
        else
          nfts_data = client.get_nfts(limit: limit, offset: offset)
        end

        # 格式化 NFT 数据
        formatted_nfts = nfts_data['nfts'].map do |nft|
          client.format_nft_for_deal(nft)
        end.compact

        render json: {
          nfts: formatted_nfts,
          total: nfts_data['total'] || formatted_nfts.length,
          limit: limit,
          offset: offset
        }
      rescue => e
        render json: { error: e.message }, status: :bad_request
      end
    end

    # GET /tangyzen/web3/collections.json
    def collections
      limit = (params[:limit] || 50).to_i.clamp(1, 100)
      offset = (params[:offset] || 0).to_i.clamp(0, 10000)

      client = OpenSeaClient.new

      begin
        collections_data = client.get_collections(limit: limit, offset: offset)

        render json: {
          collections: collections_data['collections'] || [],
          total: collections_data['total'] || 0,
          limit: limit,
          offset: offset
        }
      rescue => e
        render json: { error: e.message }, status: :bad_request
      end
    end

    # GET /tangyzen/web3/collections/:slug.json
    def show_collection
      collection_slug = params[:slug]
      client = OpenSeaClient.new

      begin
        collection_data = client.get_collection(collection_slug)
        
        # 获取该集合的前 5 个 NFT
        nfts_data = client.get_nfts(collection_slug: collection_slug, limit: 5)

        render json: {
          collection: collection_data['collection'],
          sample_nfts: nfts_data['nfts']&.map { |nft| client.format_nft_for_deal(nft) } || []
        }
      rescue => e
        render json: { error: e.message }, status: :bad_request
      end
    end

    # GET /tangyzen/web3/nfts/:contract_address/:token_id.json
    def show_nft
      contract_address = params[:contract_address]
      token_id = params[:token_id]
      chain = params[:chain] || 'ethereum'

      client = OpenSeaClient.new

      begin
        nft_data = client.get_nft(contract_address: contract_address, token_id: token_id, chain: chain)
        
        # 获取活动历史
        activity_data = client.get_nft_activity(
          contract_address: contract_address,
          token_id: token_id,
          chain: chain,
          limit: 20
        )

        formatted_nft = client.format_nft_for_deal(nft_data)

        render json: {
          nft: formatted_nft,
          raw_data: nft_data,
          activity: activity_data
        }
      rescue => e
        render json: { error: e.message }, status: :bad_request
      end
    end

    # GET /tangyzen/web3/trending.json
    def trending
      limit = (params[:limit] || 20).to_i.clamp(1, 50)

      client = OpenSeaClient.new

      begin
        trending_data = client.get_trending_collections(limit: limit)

        render json: {
          trending: trending_data['collections'] || [],
          total: trending_data['collections']&.length || 0
        }
      rescue => e
        render json: { error: e.message }, status: :bad_request
      end
    end

    # GET /tangyzen/web3/search.json
    def search
      query = params[:q]
      chain = params[:chain] || 'ethereum'
      limit = (params[:limit] || 20).to_i.clamp(1, 100)

      if query.blank?
        return render json: { error: "Query parameter 'q' is required" }, status: :bad_request
      end

      client = OpenSeaClient.new

      begin
        nfts_data = client.search_nfts(query: query, chain: chain, limit: limit)

        formatted_nfts = nfts_data['nfts']&.map do |nft|
          client.format_nft_for_deal(nft)
        end&.compact || []

        render json: {
          results: formatted_nfts,
          total: formatted_nfts.length,
          query: query
        }
      rescue => e
        render json: { error: e.message }, status: :bad_request
      end
    end

    # POST /tangyzen/web3/sync_trending.json
    def sync_trending
      unless is_staff?
        return render json: { error: I18n.t("tangyzen.errors.forbidden") }, status: :forbidden
      end

      limit = (params[:limit] || 20).to_i.clamp(1, 50)
      client = OpenSeaClient.new

      begin
        synced_deals = client.sync_trending_nfts_as_deals(limit: limit)

        render json: {
          synced_count: synced_deals.length,
          message: "Successfully synced #{synced_deals.length} NFT deals from OpenSea trending collections"
        }
      rescue => e
        render json: { error: e.message }, status: :bad_request
      end
    end

    # POST /tangyzen/web3/connect_wallet.json
    def connect_wallet
      wallet_address = params.require(:wallet_address)
      
      # 验证钱包地址格式（简单验证）
      unless wallet_address.match?(/^0x[a-fA-F0-9]{40}$/)
        return render json: { error: "Invalid wallet address format" }, status: :bad_request
      end

      # 保存钱包地址到用户自定义字段
      current_user.user_fields['web3_wallet'] = wallet_address
      
      if current_user.save
        render json: {
          connected: true,
          wallet_address: wallet_address,
          message: "Wallet connected successfully"
        }
      else
        render json: { error: "Failed to connect wallet" }, status: :unprocessable_entity
      end
    end

    # DELETE /tangyzen/web3/disconnect_wallet.json
    def disconnect_wallet
      current_user.user_fields['web3_wallet'] = nil
      
      if current_user.save
        render json: {
          disconnected: true,
          message: "Wallet disconnected successfully"
        }
      else
        render json: { error: "Failed to disconnect wallet" }, status: :unprocessable_entity
      end
    end

    # GET /tangyzen/web3/my_nfts.json
    def my_nfts
      wallet_address = current_user.user_fields['web3_wallet']
      
      if wallet_address.blank?
        return render json: { 
          error: "No wallet connected. Please connect your wallet first." 
        }, status: :bad_request
      end

      limit = (params[:limit] || 20).to_i.clamp(1, 100)
      offset = (params[:offset] || 0).to_i.clamp(0, 10000)

      client = OpenSeaClient.new

      begin
        nfts_data = client.get_user_nfts(
          wallet_address: wallet_address,
          limit: limit,
          offset: offset
        )

        formatted_nfts = nfts_data['nfts']&.map do |nft|
          client.format_nft_for_deal(nft)
        end&.compact || []

        render json: {
          nfts: formatted_nfts,
          total: nfts_data['total'] || formatted_nfts.length,
          wallet_address: wallet_address,
          limit: limit,
          offset: offset
        }
      rescue => e
        render json: { error: e.message }, status: :bad_request
      end
    end

    # GET /tangyzen/web3/floor_price.json
    def floor_price
      collection_slug = params.require(:collection)
      
      client = OpenSeaClient.new

      begin
        floor_price = client.get_floor_price(collection_slug)

        render json: {
          collection: collection_slug,
          floor_price: floor_price,
          formatted: floor_price ? "#{floor_price} ETH" : "Not available"
        }
      rescue => e
        render json: { error: e.message }, status: :bad_request
      end
    end
  end
end
