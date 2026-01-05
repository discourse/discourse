module Jobs
  class SyncWeb3 < ::Jobs::Base
    sidekiq_options queue: 'low', retry: true
    
    def execute(args)
      return unless SiteSetting.tangyzen_web3_enabled?
      
      collections = args[:collections] || []
      force_refresh = args[:force_refresh] || false
      
      if collections.empty?
        # Use featured collections from settings
        collections = featured_collections
      end
      
      collections.each do |collection_slug|
        begin
          sync_collection(collection_slug, force_refresh)
        rescue StandardError => e
          Rails.logger.error("Failed to sync collection #{collection_slug}: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
        end
      end
      
      Rails.logger.info("Web3 sync completed for #{collections.size} collections")
    end
    
    private
    
    def featured_collections
      collections = SiteSetting.tangyzen_web3_featured_collections || ''
      collections.split(',').map(&:strip).reject(&:blank?)
    end
    
    def sync_collection(collection_slug, force_refresh)
      client = Tangyzen::OpenSeaClient.new
      
      # Get collection data
      collection = client.get_collection(collection_slug)
      Rails.logger.info("Syncing collection: #{collection['name']}")
      
      # Get NFTs from collection
      nfts = client.get_collection_nfts(collection_slug, limit: 20)
      Rails.logger.info("Found #{nfts.size} NFTs")
      
      # Create deals from NFTs
      created_count = 0
      updated_count = 0
      
      nfts.each do |nft|
        result = create_or_update_nft_deal(nft, collection, force_refresh)
        if result == :created
          created_count += 1
        elsif result == :updated
          updated_count += 1
        end
      end
      
      Rails.logger.info("Created: #{created_count}, Updated: #{updated_count}")
    end
    
    def create_or_update_nft_deal(nft, collection, force_refresh)
      # Check if deal already exists
      existing = Tangyzen::Deal.find_by(opensea_token_id: nft['identifier'])
      
      if existing
        return :unchanged unless force_refresh
        
        # Update existing deal
        existing.update(
          title: nft['name'] || "#{collection['name']} ##{nft['identifier']}",
          description: nft['description'] || collection['description'],
          original_price: parse_price(nft['current_price']),
          discounted_price: parse_price(nft['current_price']),
          discount_percentage: 0,
          image_url: nft['image_url'],
          featured: should_feature?(collection),
          updated_at: Time.now
        )
        
        return :updated
      end
      
      # Create new deal from NFT
      Tangyzen::Deal.create!(
        title: nft['name'] || "#{collection['name']} ##{nft['identifier']}",
        description: nft['description'] || collection['description'],
        original_price: parse_price(nft['current_price']),
        discounted_price: parse_price(nft['current_price']),
        discount_percentage: 0,
        store: 'OpenSea',
        product_url: nft['opensea_url'],
        image_url: nft['image_url'],
        expiry_date: nil,
        user_id: Discourse.system_user.id,
        category_id: get_or_create_nft_category,
        opensea_token_id: nft['identifier'],
        opensea_collection_slug: collection['slug'],
        featured: should_feature?(collection),
        status: 'published'
      )
      
      return :created
    end
    
    def parse_price(price_string)
      return 0 if price_string.blank?
      
      # OpenSea returns price in ETH, convert to float
      price_string.to_f
    end
    
    def should_feature?(collection)
      # Feature collections with high volume or floor price
      stats = collection['stats'] || {}
      stats['one_day_volume'].to_f > 10 || stats['floor_price'].to_f > 0.5
    end
    
    def get_or_create_nft_category
      # Find or create NFT category
      category = Category.find_by(slug: 'nfts')
      
      unless category
        category = Category.create!(
          name: 'NFTs',
          slug: 'nfts',
          color: 'FF6B6B',
          text_color: 'FFFFFF',
          user_id: Discourse.system_user.id,
          permissions: { everyone: :full }
        )
      end
      
      category.id
    end
  end
end
