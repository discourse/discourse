# frozen_string_literal: true

class CreateTangyzenTables < ActiveRecord::Migration[7.0]
  def change
    # Create content types table
    create_table :tangyzen_content_types do |t|
      t.string :name, null: false
      t.string :icon, null: false
      t.string :color, null: false
      t.timestamps
    end
    
    add_index :tangyzen_content_types, :name, unique: true
    
    # Create deals table
    create_table :tangyzen_deals do |t|
      t.references :topic, foreign_key: true, null: false
      t.references :user, foreign_key: { to_table: :users }, null: false
      t.references :category, foreign_key: { to_table: :categories }
      
      # Deal specific fields
      t.decimal :original_price, precision: 10, scale: 2
      t.decimal :current_price, precision: 10, scale: 2
      t.float :discount_percentage
      t.string :deal_url
      t.string :store_name
      t.string :coupon_code
      t.datetime :expiry_date
      t.string :image_url
      t.string :store_logo_url
      
      # Metadata
      t.boolean :is_featured, default: false
      t.boolean :is_active, default: true
      t.integer :views_count, default: 0
      t.integer :clicks_count, default: 0
      t.float :hotness_score, default: 0.0
      
      t.timestamps
    end
    
    add_index :tangyzen_deals, :topic_id, unique: true
    add_index :tangyzen_deals, :user_id
    add_index :tangyzen_deals, :is_featured
    add_index :tangyzen_deals, :is_active
    add_index :tangyzen_deals, :expiry_date
    add_index :tangyzen_deals, :hotness_score
    add_index :tangyzen_deals, [:store_name, :is_active]
    
    # Create music table
    create_table :tangyzen_music do |t|
      t.references :topic, foreign_key: true, null: false
      t.references :user, foreign_key: { to_table: :users }, null: false
      t.references :category, foreign_key: { to_table: :categories }
      
      # Music specific fields
      t.string :artist_name
      t.string :album_name
      t.string :genre
      t.string :spotify_url
      t.string :apple_music_url
      t.string :youtube_url
      t.string :soundcloud_url
      t.string :cover_image_url
      t.string :release_date
      
      # Metadata
      t.boolean :is_featured, default: false
      t.boolean :is_active, default: true
      t.integer :likes_count, default: 0
      t.integer :plays_count, default: 0
      t.float :hotness_score, default: 0.0
      
      t.timestamps
    end
    
    add_index :tangyzen_music, :topic_id, unique: true
    add_index :tangyzen_music, :user_id
    add_index :tangyzen_music, :genre
    add_index :tangyzen_music, :is_featured
    add_index :tangyzen_music, :hotness_score
    
    # Create movies table
    create_table :tangyzen_movies do |t|
      t.references :topic, foreign_key: true, null: false
      t.references :user, foreign_key: { to_table: :users }, null: false
      t.references :category, foreign_key: { to_table: :categories }
      
      # Movie specific fields
      t.string :title
      t.string :type # movie or series
      t.string :director
      t.string :actors, array: true
      t.string :genres, array: true
      t.decimal :rating, precision: 3, scale: 1
      t.integer :year
      t.string :poster_url
      t.string :trailer_url
      t.string :netflix_url
      t.string :amazon_url
      t.string :hulu_url
      t.string :duration
      t.string :age_rating
      
      # Metadata
      t.boolean :is_featured, default: false
      t.boolean :is_active, default: true
      t.integer :likes_count, default: 0
      t.integer :views_count, default: 0
      t.float :hotness_score, default: 0.0
      
      t.timestamps
    end
    
    add_index :tangyzen_movies, :topic_id, unique: true
    add_index :tangyzen_movies, :user_id
    add_index :tangyzen_movies, :rating
    add_index :tangyzen_movies, :year
    add_index :tangyzen_movies, :is_featured
    add_index :tangyzen_movies, :hotness_score
    
    # Create reviews table
    create_table :tangyzen_reviews do |t|
      t.references :topic, foreign_key: true, null: false
      t.references :user, foreign_key: { to_table: :users }, null: false
      t.references :category, foreign_key: { to_table: :categories }
      
      # Review specific fields
      t.string :product_name
      t.string :brand
      t.string :category_name
      t.integer :rating # 1-5 stars
      t.text :pros, array: true
      t.text :cons, array: true
      t.string :product_url
      t.string :product_image_url
      t.decimal :price, precision: 10, scale: 2
      t.string :purchase_date
      t.string :verified_purchase # true/false
      
      # Metadata
      t.boolean :is_featured, default: false
      t.boolean :is_active, default: true
      t.integer :likes_count, default: 0
      t.integer :helpful_count, default: 0
      t.float :hotness_score, default: 0.0
      
      t.timestamps
    end
    
    add_index :tangyzen_reviews, :topic_id, unique: true
    add_index :tangyzen_reviews, :user_id
    add_index :tangyzen_reviews, :rating
    add_index :tangyzen_reviews, :is_featured
    add_index :tangyzen_reviews, :hotness_score
    
    # Create arts table
    create_table :tangyzen_arts do |t|
      t.references :topic, foreign_key: true, null: false
      t.references :user, foreign_key: { to_table: :users }, null: false
      t.references :category, foreign_key: { to_table: :categories }
      
      # Art specific fields
      t.string :title
      t.string :medium # digital, oil, watercolor, photography, etc.
      t.string :dimensions
      t.string :tools
      t.string :image_url
      t.string :thumbnail_url
      t.text :description
      t.string :inspiration
      
      # Metadata
      t.boolean :is_featured, default: false
      t.boolean :is_active, default: true
      t.integer :likes_count, default: 0
      t.integer :views_count, default: 0
      t.float :hotness_score, default: 0.0
      
      t.timestamps
    end
    
    add_index :tangyzen_arts, :topic_id, unique: true
    add_index :tangyzen_arts, :user_id
    add_index :tangyzen_arts, :medium
    add_index :tangyzen_arts, :is_featured
    add_index :tangyzen_arts, :hotness_score
    
    # Create blogs table
    create_table :tangyzen_blogs do |t|
      t.references :topic, foreign_key: true, null: false
      t.references :user, foreign_key: { to_table: :users }, null: false
      t.references :category, foreign_key: { to_table: :categories }
      
      # Blog specific fields
      t.string :title
      t.string :featured_image_url
      t.string :author_name
      t.string :author_avatar_url
      t.integer :reading_time
      t.string :excerpt
      t.string :tags, array: true
      t.datetime :published_at
      
      # Metadata
      t.boolean :is_featured, default: false
      t.boolean :is_active, default: true
      t.boolean :is_published, default: true
      t.integer :likes_count, default: 0
      t.integer :views_count, default: 0
      t.integer :shares_count, default: 0
      t.float :hotness_score, default: 0.0
      
      t.timestamps
    end
    
    add_index :tangyzen_blogs, :topic_id, unique: true
    add_index :tangyzen_blogs, :user_id
    add_index :tangyzen_blogs, :is_published
    add_index :tangyzen_blogs, :published_at
    add_index :tangyzen_blogs, :is_featured
    add_index :tangyzen_blogs, :hotness_score
    
    # Create gaming table
    create_table :tangyzen_gaming do |t|
      t.references :topic, foreign_key: true, null: false
      t.references :user, foreign_key: { to_table: :users }, null: false
      t.references :category, foreign_key: { to_table: :categories }
      
      # Gaming specific fields
      t.string :title
      t.text :description
      t.string :game_name
      t.string :genre
      t.string :platform
      t.string :developer
      t.string :publisher
      t.date :release_date
      t.string :age_rating
      t.boolean :multiplayer, default: false
      t.boolean :coop, default: false
      t.decimal :rating, precision: 3, scale: 1
      t.decimal :playtime_hours, precision: 6, scale: 1
      t.boolean :dlc_available, default: false
      t.boolean :in_game_purchases, default: false
      t.boolean :cross_platform, default: false
      t.boolean :free_to_play, default: false
      t.string :cover_image_url
      t.text :screenshot_urls
      t.string :video_url
      t.string :website_url
      
      # Metadata
      t.boolean :featured, default: false
      t.datetime :featured_at
      t.string :status, default: 'published'
      t.integer :like_count, default: 0
      t.integer :save_count, default: 0
      t.integer :view_count, default: 0
      
      t.timestamps
    end
    
    add_index :tangyzen_gaming, :topic_id, unique: true
    add_index :tangyzen_gaming, :user_id
    add_index :tangyzen_gaming, :genre
    add_index :tangyzen_gaming, :platform
    add_index :tangyzen_gaming, :rating
    add_index :tangyzen_gaming, :featured
    add_index :tangyzen_gaming, :status
    add_index :tangyzen_gaming, :view_count
    add_index :tangyzen_gaming, :like_count
    
    # Create content likes table
    create_table :tangyzen_likes do |t|
      t.references :user, foreign_key: { to_table: :users }, null: false
      t.string :content_type, null: false # deal, music, movie, review, art, blog
      t.integer :content_id, null: false
      t.timestamps
    end
    
    add_index :tangyzen_likes, [:user_id, :content_type, :content_id], unique: true
    add_index :tangyzen_likes, [:content_type, :content_id]
    
    # Create content saves table
    create_table :tangyzen_saves do |t|
      t.references :user, foreign_key: { to_table: :users }, null: false
      t.string :content_type, null: false
      t.integer :content_id, null: false
      t.timestamps
    end
    
    add_index :tangyzen_saves, [:user_id, :content_type, :content_id], unique: true
    add_index :tangyzen_saves, [:content_type, :content_id]
    
    # Create content clicks table (for tracking deal clicks)
    create_table :tangyzen_clicks do |t|
      t.string :content_type, null: false
      t.integer :content_id, null: false
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end
    
    add_index :tangyzen_clicks, [:content_type, :content_id]
    add_index :tangyzen_clicks, :created_at
    
    # Insert default content types
    reversible do |dir|
      dir.up do
        Tangyzen::ContentType.create!(
          name: 'deal',
          icon: '💰',
          color: '#10b981'
        )
        Tangyzen::ContentType.create!(
          name: 'music',
          icon: '🎵',
          color: '#8b5cf6'
        )
        Tangyzen::ContentType.create!(
          name: 'movie',
          icon: '🍿',
          color: '#f59e0b'
        )
        Tangyzen::ContentType.create!(
          name: 'review',
          icon: '⚖️',
          color: '#ef4444'
        )
        Tangyzen::ContentType.create!(
          name: 'art',
          icon: '📸',
          color: '#06b6d4'
        )
        Tangyzen::ContentType.create!(
          name: 'blog',
          icon: '✍️',
          color: '#3b82f6'
        )
        Tangyzen::ContentType.create!(
          name: 'gaming',
          icon: '🎮',
          color: '#ec4899'
        )
      end
    end
  end
end
