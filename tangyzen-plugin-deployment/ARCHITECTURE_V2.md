# TangyZen Deals v2.0 - Architecture Overview

## 📐 Page Architecture

The platform is now organized into **2 main pages** with distinct purposes:

### Page 1: Deals Page (`/deals`)
**Purpose**: Dedicated page for browsing and sharing deals, coupons, and discounts

**Features**:
- Deal-specific filtering (price range, discount percentage, category, store)
- Sorting by hot, new, expiring soon, price
- Deal submission form
- Real-time deal updates

**Components**:
- `deals-page.js.es6` - Main page widget
- `deal-card.js.es6` - Individual deal display

**Route**: `/deals`

### Page 2: Content Hub (`/content` or `/explore`)
**Purpose**: Unified hub for all 6 UGC content types (Gaming, Music, Movies, Reviews, Arts, Blogs)

**Features**:
- Tab-based navigation between content types
- Unified sorting (Trending, Latest, Featured)
- Content type-specific cards
- Real-time content loading

**Components**:
- `content-hub.js.es6` - Main hub widget with tabs
- `gaming-card.js.es6` - Gaming content display
- Integrated inline components for music, movies, reviews, arts, blogs

**Route**: `/content` or `/explore`

## 🎨 Frontend Architecture

### Widget System
All UI components use Discourse's widget system for maximum compatibility:

```javascript
// Widget registration
export default createWidget("widget-name", {
  tagName: "div.css-class",
  buildKey: (attrs) => `key-${attrs.id}`,
  defaultState() { return {} },
  html(attrs, state) { return h() }
});
```

### Component Hierarchy

```
Application Layer
├── Deals Page (/deals)
│   ├── deals-page.js.es6 (Main Widget)
│   │   ├── Filter Panel
│   │   ├── Sort Tabs
│   │   └── deal-card (Repeated)
│   └── submit-deal.js.es6 (Modal)
│
├── Content Hub (/content)
│   ├── content-hub.js.es6 (Main Widget)
│   │   ├── Tab Navigation
│   │   └── Content Grid
│   │       ├── gaming-card (for Gaming tab)
│   │       ├── music-card (inline, for Music tab)
│   │       ├── movie-card (inline, for Movies tab)
│   │       ├── review-card (inline, for Reviews tab)
│   │       ├── art-card (inline, for Arts tab)
│   │       └── blog-card (inline, for Blogs tab)
│
└── Web3 Dashboard (/web3)
    └── web3-dashboard.js.es6
        ├── Wallet Connection
        ├── Trending NFTs
        ├── Collections Browser
        ├── My NFTs
        └── Search
```

### State Management
Each widget manages its own state:

```javascript
defaultState() {
  return {
    activeTab: "gaming",
    content: { gaming: [], music: [], ... },
    loading: false,
    filters: { sort: "trending" }
  };
}
```

## 🔌 API Architecture

### RESTful Endpoints

#### Content Types (6 types × 8-9 endpoints = 52 endpoints)
```
GET    /tangyzen/:type            # List all
GET    /tangyzen/:type/featured   # Featured items
GET    /tangyzen/:type/trending   # Trending items
GET    /tangyzen/:type/:id        # Single item
POST   /tangyzen/:type            # Create
PUT    /tangyzen/:type/:id        # Update
DELETE /tangyzen/:type/:id        # Delete
POST   /tangyzen/:type/:id/like   # Like
DELETE /tangyzen/:type/:id/unlike # Unlike
POST   /tangyzen/:type/:id/save   # Save
DELETE /tangyzen/:type/:id/unsave # Unsave
PUT    /tangyzen/:type/:id/feature# Feature (admin)
```

Types: `gaming`, `music`, `movies`, `reviews`, `arts`, `blogs`

#### Web3 Endpoints (10 endpoints)
```
GET    /tangyzen/web3/nfts                # Browse NFTs
GET    /tangyzen/web3/collections         # Browse collections
GET    /tangyzen/web3/collections/:slug   # Collection details
GET    /tangyzen/web3/nfts/:contract/:token # NFT details
GET    /tangyzen/web3/trending            # Trending NFTs
GET    /tangyzen/web3/search              # Search NFTs
POST   /tangyzen/web3/sync_trending      # Sync as deals
POST   /tangyzen/web3/connect_wallet     # Connect wallet
DELETE /tangyzen/web3/disconnect_wallet  # Disconnect wallet
GET    /tangyzen/web3/my_nfts             # My NFTs
GET    /tangyzen/web3/floor_price         # Floor price
```

## 🗄️ Database Architecture

### Schema Overview

```sql
Content Tables (7):
├── tangyzen_deals        (Deals & Coupons)
├── tangyzen_gaming       (Games & Gaming Content)
├── tangyzen_music        (Music & Albums)
├── tangyzen_movies       (Movies & TV Shows)
├── tangyzen_reviews      (Product Reviews)
├── tangyzen_arts        (Visual Arts)
└── tangyzen_blogs        (Blog Posts)

Auxiliary Tables (4):
├── tangyzen_content_types   (Content Type Metadata)
├── tangyzen_likes         (Polymorphic Likes)
├── tangyzen_saves         (Polymorphic Saves)
└── tangyzen_clicks        (Deal Click Tracking)
```

### Relationships

```
User ──< creates >── Content Tables
Content ──< has_many >── Likes
Content ──< has_many >── Saves
Content ──< belongs_to >── Category
Content ──< belongs_to >── Topic (Discourse integration)
```

## 🔐 Security Architecture

### Authentication
- Discourse session-based authentication
- User roles: Admin, Staff, User, Guest

### Authorization
```
Guest:  View only
User:   View, Create, Edit Own, Like, Save
Staff:   All User actions + Feature content
Admin:   All actions + Delete any, Plugin Settings
```

### API Security
- CSRF tokens on all state-changing requests
- Rate limiting (configurable)
- Input validation and sanitization
- SQL injection prevention via ActiveRecord
- XSS protection via Discourse sanitization

## 🎨 UI/UX Design

### Color Scheme
- **Primary**: Gradient Green (#10b981) to Blue (#3b82f6)
- **Deals**: Red/Orange gradient (#ef4444 to #f97316)
- **Web3**: Green (#10b981) with Purple (#8b5cf6)
- **Gaming**: Pink (#ec4899)

### Responsive Breakpoints
- Mobile: < 768px
- Tablet: 768px - 1024px
- Desktop: > 1024px

### Interaction Patterns
- Hover effects with smooth transitions
- Skeleton loading states
- Infinite scroll support
- Modal dialogs for forms
- Toast notifications for actions

## 🚀 Performance Optimization

### Frontend
- Lazy loading for images
- Virtual DOM (Ember.js)
- Code splitting
- Asset minification
- Browser caching

### Backend
- Database indexing on foreign keys and filters
- Query result caching
- Connection pooling
- Pagination (default 20, max 100)
- API response compression

### Web3
- OpenSea API response caching
- Trending NFTs sync job (scheduled)
- Rate limiting to respect API quotas

## 📊 Data Flow

### Typical User Flow

```
User Action
    ↓
Widget State Update
    ↓
AJAX Request to API
    ↓
Controller Processes Request
    ↓
Model Queries Database
    ↓
Serializer Formats Response
    ↓
JSON Response Returns
    ↓
Widget Renders Updated UI
```

### Web3 Integration Flow

```
User Views NFT
    ↓
widget calls OpenSeaClient
    ↓
OpenSeaClient.request()
    ↓
OpenSea API Response
    ↓
format_nft_for_deal()
    ↓
NFT Card Renders
```

## 🔌 Extension Points

### Adding New Content Type

1. Create Model: `app/models/tangyzen/new_type.rb`
2. Create Serializer: `app/serializers/tangyzen/new_type_serializer.rb`
3. Create Controller: `app/controllers/tangyzen/new_type_controller.rb`
4. Add Route: `config/routes.rb`
5. Add to Content Hub: Update `content-hub.js.es6`
6. Add Migration: Update database schema

### Adding New Widget

1. Create Widget: `assets/javascripts/discourse/tangyzen/components/new_widget.js.es6`
2. Create Template: `assets/javascripts/discourse/tangyzen/templates/new_widget.hbs`
3. Add Styles: `assets/stylesheets/tangyzen/new_widget.scss`
4. Register in Initializer: `init-tangyzen.js.es6`

## 📝 Naming Conventions

### Backend
- Models: PascalCase (e.g., `Gaming`)
- Controllers: PascalCase + _controller (e.g., `GamingController`)
- Serializers: PascalCase + _serializer (e.g., `GamingSerializer`)
- Tables: snake_case with prefix (e.g., `tangyzen_gaming`)
- Routes: snake_case (e.g., `/tangyzen/gaming`)

### Frontend
- Widgets: kebab-case (e.g., `gaming-card`)
- Templates: kebab-case.hbs (e.g., `content-hub.hbs`)
- Styles: kebab-case.scss (e.g., `gaming.scss`)
- Component Names: kebab-case (e.g., `content-hub`)

---

**TangyZen Deals v2.0 Architecture**  
Last Updated: January 5, 2026
