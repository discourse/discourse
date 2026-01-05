# TangyZen Discourse Plugin

This is a custom Discourse plugin for TangyZen platform, adding UGC content types including Deals, Music, Movies, Reviews, Art, and Blog posts.

## Features

- **Content Types**: 6 custom post types (Deal, Music, Movie, Review, Art, Blog)
- **Custom Fields**: Type-specific metadata for each content type
- **Enhanced Display**: Beautiful cards and layouts for each content type
- **SEO Optimized**: Rich snippets and metadata
- **Search Integration**: Filter by content type
- **Category System**: Custom categories for each content type

## Installation

```bash
# Copy to Discourse plugins directory
cd /var/discourse/plugins
git clone <repository-url> tangyzen-plugin

# Rebuild Discourse
cd /var/discourse
./launcher rebuild app
```

## Usage

After installation, you can create custom content types through the composer's "Deal" button or via API.
