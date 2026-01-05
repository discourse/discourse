# frozen_string_literal: true

module Tangyzen
  class OpenSeaClient
    BASE_URL = 'https://api.opensea.io/api/v2'
    
    # 从 Discourse 插件设置中获取 API Token
    def self.api_token
      SiteSetting.tangyzen_opensea_api_token || ENV['OPENSEA_API_TOKEN'] || '3bfaca9964d74c08b42958d9319208e3'
    end
    
    def initialize
      @token = self.class.api_token
    end

    # 获取 NFT 集合列表
    def get_collections(limit: 50, offset: 0)
      get("/collections", limit: limit, offset: offset)
    end

    # 获取特定 NFT 集合详情
    def get_collection(collection_slug)
      get("/collections/#{collection_slug}")
    end

    # 获取 NFT 列表
    def get_nfts(collection_slug: nil, owner: nil, limit: 50, offset: 0)
      params = { limit: limit, offset: offset }
      params[:collection] = collection_slug if collection_slug
      params[:owner] = owner if owner
      
      get("/nfts", **params)
    end

    # 获取特定 NFT 详情
    def get_nft(contract_address: nil, token_id: nil, chain: 'ethereum')
      raise ArgumentError, "contract_address and token_id are required" if contract_address.blank? || token_id.blank?
      
      get("/nfts/#{chain}/#{contract_address}/#{token_id}")
    end

    # 搜索 NFT
    def search_nfts(query:, chain: 'ethereum', limit: 20)
      get("/nfts", query: query, chain: chain, limit: limit)
    end

    # 获取 NFT 活动（交易历史）
    def get_nft_activity(contract_address:, token_id:, chain: 'ethereum', limit: 50)
      get("/nfts/#{chain}/#{contract_address}/#{token_id}/activity", limit: limit)
    end

    # 获取用户拥有的 NFT
    def get_user_nfts(wallet_address:, chain: 'ethereum', limit: 50, offset: 0)
      get("/chain/#{chain}/account/#{wallet_address}/nfts", limit: limit, offset: offset)
    end

    # 获取热门集合（基于交易量）
    def get_trending_collections(limit: 20)
      get("/collections/trending", limit: limit)
    end

    # 获取地板价
    def get_floor_price(collection_slug)
      collection = get_collection(collection_slug)
      return nil unless collection && collection['collection']
      
      stats = collection['collection']['stats']
      stats ? stats['floor_price'] : nil
    end

    # 格式化 NFT 数据为 TangyZen 格式
    def format_nft_for_deal(nft_data, collection_data = nil)
      collection = collection_data || nft_data['collection']
      return nil unless collection

      {
        title: "#{collection['name']} - #{nft_data['name'] || 'NFT'}",
        description: nft_data['description'] || collection['description'],
        original_price: nft_data['last_sale']&.dig('total_price')&.to_f || 0.0,
        current_price: nft_data['listing']&.dig('price')&.to_f || 0.0,
        discount_percentage: calculate_discount(nft_data),
        expires_at: nft_data['listing']&.dig('closing_date'),
        image_url: nft_data['image_url'] || nft_data['thumbnail_url'] || collection['image_url'],
        external_url: nft_data['opensea_url'],
        merchant: "OpenSea - #{collection['name']}",
        category: 'NFT',
        tags: ['nft', 'web3', collection['name']&.downcase, collection['chain']],
        deal_type: 'nft',
        verified: collection['safelist_request_status'] == 'verified',
        stock_quantity: nft_data['token_id'] ? 1 : nil,
        metadata: {
          contract_address: nft_data['contract'],
          token_id: nft_data['token_id'],
          chain: nft_data['chain'] || 'ethereum',
          collection_slug: collection['slug'],
          collection_name: collection['name'],
          creator: nft_data['creator']&.dig('address'),
          traits: nft_data['traits'],
          rarity_score: calculate_rarity_score(nft_data),
          last_sale_price: nft_data['last_sale']&.dig('total_price'),
          last_sale_date: nft_data['last_sale']&.dig('event_timestamp'),
          floor_price: collection['stats']&.dig('floor_price'),
          total_supply: collection['stats']&.dig('total_supply'),
          total_owners: collection['stats']&.dig('num_owners')
        }
      }
    end

    # 同步 OpenSea 热门 NFT 作为 Deals
    def sync_trending_nfts_as_deals(limit: 20)
      trending = get_trending_collections(limit: limit)
      return [] unless trending && trending['collections']

      synced_deals = []
      
      trending['collections'].each do |collection|
        begin
          nfts = get_nfts(collection_slug: collection['slug'], limit: 5)
          next unless nfts && nfts['nfts']

          nfts['nfts'].first(3).each do |nft|
            deal_data = format_nft_for_deal(nft, collection)
            next unless deal_data

            # 检查是否已存在（通过外部链接）
            existing_deal = Deal.find_by(external_url: nft['opensea_url'])
            
            if existing_deal
              # 更新现有 Deal
              existing_deal.update(deal_data.except(:title, :original_price))
              synced_deals << existing_deal
            else
              # 创建新 Deal
              deal = Deal.create(deal_data)
              synced_deals << deal if deal.persisted?
            end
          end
        rescue => e
          Rails.logger.error "Error syncing NFT from #{collection['slug']}: #{e.message}"
          next
        end
      end

      synced_deals
    end

    private

    def get(endpoint, **params)
      uri = URI("#{BASE_URL}#{endpoint}")
      uri.query = URI.encode_www_form(params.compact) if params.any?

      request = Net::HTTP::Get.new(uri)
      request['X-API-KEY'] = @token
      request['Content-Type'] = 'application/json'

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      handle_response(response)
    end

    def handle_response(response)
      case response.code.to_i
      when 200..299
        JSON.parse(response.body)
      when 401
        raise "OpenSea API authentication failed. Check your API token."
      when 403
        raise "OpenSea API access forbidden. Check your API permissions."
      when 404
        raise "OpenSea resource not found."
      when 429
        raise "OpenSea API rate limit exceeded. Please try again later."
      else
        raise "OpenSea API error: #{response.code} - #{response.body}"
      end
    end

    def calculate_discount(nft_data)
      return 0 unless nft_data['last_sale'] && nft_data['listing']
      
      last_price = nft_data['last_sale']['total_price']&.to_f || 0
      current_price = nft_data['listing']['price']&.to_f || 0
      
      return 0 if last_price == 0 || current_price == 0
      return 0 if current_price > last_price
      
      ((last_price - current_price) / last_price * 100).round(2)
    end

    def calculate_rarity_score(nft_data)
      # 简化的稀有度计算（实际应该基于 trait rarity）
      traits = nft_data['traits'] || []
      return 0 if traits.empty?
      
      # 基于属性数量的简单评分
      base_score = 50
      trait_bonus = traits.length * 10
      rare_traits = traits.select { |t| t['trait_type'].include?('Rare') || t['value'].include?('Rare') }.length * 20
      
      (base_score + trait_bonus + rare_traits).clamp(0, 100)
    end
  end
end
