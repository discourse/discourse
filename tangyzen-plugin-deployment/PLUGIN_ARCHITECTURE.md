# TangyZen Discourse Plugin Architecture

## Overview

This plugin extends Discourse with 6 custom UGC content types: Deals, Music, Movies, Reviews, Art, and Blog posts.

## Directory Structure

```
tangyzen-discourse/
├── plugin.rb                          # Plugin manifest and initialization
├── config/                            # Configuration
│   └── settings.yml                   # Plugin settings schema
├── app/                               # Rails application code
│   ├── controllers/                     # Custom controllers
│   │   └── tangyzen/                  
│   │       ├── deals_controller.rb       # Deal submissions
│   │       ├── music_controller.rb       # Music posts
│   │       ├── movies_controller.rb      # Movie recommendations
│   │       ├── reviews_controller.rb     # Product reviews
│   │       ├── arts_controller.rb       # Art posts
│   │       └── blogs_controller.rb      # Blog posts
│   ├── models/                          # Custom models
│   │   └── tangyzen/
│   │       ├── content_type.rb
│   │       └── custom_field.rb
│   ├── serializers/                      # API serializers
│   │   └── tangyzen/
│   │       ├── deal_serializer.rb
│   │       ├── music_serializer.rb
│   │       └── ...
│   ├── jobs/                            # Background jobs
│   │   └── tangyzen/
│   │       ├── sync_job.rb
│   │       └── notification_job.rb
│   └── services/                        # Business logic
│       └── tangyzen/
│           ├── content_service.rb
│           ├── notification_service.rb
│           └── search_service.rb
├── db/                                # Database migrations
│   └── migrate/
│       ├── 001_create_tangyzen_content_types.rb
│       ├── 002_create_tangyzen_custom_fields.rb
│       └── ...
├── assets/                             # JavaScript and CSS
│   └── javascripts/
│       └── discourse/
│           └── tangyzen/
│               ├── components/
│               │   ├── deal-card.js.es6
│               │   ├── music-card.js.es6
│               │   ├── deal-form.js.es6
│               │   └── ...
│               ├── initializers/
│               │   └── init.js.es6
│               └── routes/
│                   └── discourse-router-map.js.es6
└── lib/                               # Library code
    └── tangyzen_engine.rb
```

## Content Types

### 1. Deal (优惠交易)
- Fields: original_price, current_price, discount_percentage, deal_url, store_name, coupon_code, expiry_date
- Display: Price comparison, discount badge, expiry timer, store logo

### 2. Music (音乐发现)
- Fields: artist_name, album_name, genre, spotify_url, youtube_url, soundcloud_url
- Display: Album art, audio player, streaming links, genre tags

### 3. Movie (影视推荐)
- Fields: director, cast[], imdb_rating, release_year, duration_minutes, streaming_platform
- Display: Poster, rating stars, cast list, streaming availability

### 4. Review (产品测评)
- Fields: product_name, brand, rating, pros[], cons[], images[]
- Display: Rating stars, pros/cons list, product images, verdict

### 5. Art (视觉艺术)
- Fields: medium, dimensions, tools_used[], images[]
- Display: Gallery, medium badge, tools list, high-res viewer

### 6. Blog (博客文章)
- Fields: featured_image_url, reading_time_minutes, author_bio
- Display: Featured image, reading time, author info, related posts

## API Endpoints

### Content Creation
- `POST /tangyzen/deals` - Create new deal
- `POST /tangyzen/music` - Create new music post
- `POST /tangyzen/movies` - Create new movie post
- `POST /tangyzen/reviews` - Create new review
- `POST /tangyzen/arts` - Create new art post
- `POST /tangyzen/blogs` - Create new blog post

### Content Retrieval
- `GET /tangyzen/deals` - List deals (with filters)
- `GET /tangyzen/deals/:id` - Get deal details
- `GET /tangyzen/music` - List music posts
- `GET /tangyzen/music/:id` - Get music post details
- `...` (similar for other types)

### Filters and Search
- `?category=x` - Filter by category
- `?sort=popular` - Sort by popularity
- `?q=searchterm` - Search
- `?tags=tag1,tag2` - Filter by tags

## Database Schema

### Custom Tables

```sql
-- Content types
CREATE TABLE tangyzen_content_types (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) NOT NULL UNIQUE,
  slug VARCHAR(50) NOT NULL UNIQUE,
  icon VARCHAR(50),
  color VARCHAR(7),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Custom fields per content type
CREATE TABLE tangyzen_custom_fields (
  id SERIAL PRIMARY KEY,
  content_type_id INTEGER REFERENCES tangyzen_content_types(id),
  post_id INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  key VARCHAR(100) NOT NULL,
  value JSONB,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(content_type_id, post_id, key)
);

-- Indexes
CREATE INDEX idx_custom_fields_post ON tangyzen_custom_fields(post_id);
CREATE INDEX idx_custom_fields_type ON tangyzen_custom_fields(content_type_id);
```

## Custom Routes

```
/tangyzen/deals          - Deals index page
/tangyzen/deals/new      - Create new deal
/tangyzen/music          - Music index page
/tangyzen/music/new      - Create new music post
/tangyzen/movies         - Movies index page
/tangyzen/reviews        - Reviews index page
/tangyzen/arts           - Art gallery
/tangyzen/blogs          - Blog index page
/admin/plugins/tangyzen  - Plugin settings
```
