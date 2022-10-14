# frozen_string_literal: true

class HashtagService
  HASHTAGS_PER_REQUEST = 20

  attr_reader :guardian
  cattr_reader :data_sources

  def self.register_data_source(type, &block)
    @@data_sources[type] = block
  end

  def self.clear_data_sources
    @@data_sources = {}

    register_data_source("category") do |guardian, term, limit|
      Site.new(guardian).categories.select do |category|
        category[:name].downcase.include?(term.downcase)
      end.take(limit).map do |category|
        HashtagItem.new.tap do |item|
          item.text = category[:name]
          item.slug = category[:slug]
          item.icon = "folder"
        end
      end
    end

    register_data_source("tag") do |guardian, term, limit|
      tags_with_counts, _ = DiscourseTagging.filter_allowed_tags(
        guardian,
        term: term,
        with_context: true,
        limit: limit
      )
      TagsController.tag_counts_json(tags_with_counts).take(limit).map do |tag|
        HashtagItem.new.tap do |item|
          item.text = "#{tag[:name]} x #{tag[:count]}"
          item.slug = tag[:name]
          item.icon = "tag"
        end
      end
    end
  end

  clear_data_sources

  class HashtagItem
    attr_accessor :text
    attr_accessor :slug
    attr_accessor :icon
  end

  def initialize(guardian)
    @guardian = guardian
  end

  def load_from_slugs(slugs)
    all_slugs = []
    tag_slugs = []

    slugs[0..HashtagService::HASHTAGS_PER_REQUEST].each do |slug|
      if slug.end_with?(PrettyText::Helpers::TAG_HASHTAG_POSTFIX)
        tag_slugs << slug.chomp(PrettyText::Helpers::TAG_HASHTAG_POSTFIX)
      else
        all_slugs << slug
      end
    end

    # Try to resolve hashtags as categories first
    category_slugs_and_ids = all_slugs.map { |slug| [slug, Category.query_from_hashtag_slug(slug)&.id] }.to_h
    category_ids_and_urls = Category
      .secured(guardian)
      .select(:id, :slug, :parent_category_id) # fields required for generating category URL
      .where(id: category_slugs_and_ids.values)
      .map { |c| [c.id, c.url] }
      .to_h
    categories_hashtags = {}
    category_slugs_and_ids.each do |slug, id|
      if category_url = category_ids_and_urls[id]
        categories_hashtags[slug] = category_url
      end
    end

    # Resolve remaining hashtags as tags
    tag_hashtags = {}
    if SiteSetting.tagging_enabled
      tag_slugs += (all_slugs - categories_hashtags.keys)
      DiscourseTagging.filter_visible(Tag.where_name(tag_slugs), guardian).each do |tag|
        tag_hashtags[tag.name] = tag.full_url
      end
    end

    { categories: categories_hashtags, tags: tag_hashtags }
  end

  def search(term, order, limit = 5)
    results = []

    order.select { |type| @@data_sources.keys.include?(type) }.each do |type|
      if @@data_sources.key?(type)
        data = @@data_sources[type].call(guardian, term, limit)
        next if !data.all? { |item| item.kind_of?(HashtagItem) }
        results.concat(data)
      end

      # don't want to keep querying if we already reached the limit
      break if results.length == limit
    end

    results.take(limit)
  end
end
