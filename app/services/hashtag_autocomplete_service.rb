# frozen_string_literal: true

class HashtagAutocompleteService
  HASHTAGS_PER_REQUEST = 20
  SEARCH_MAX_LIMIT = 20

  attr_reader :guardian
  cattr_reader :data_sources, :contexts

  def self.register_data_source(type, klass)
    @@data_sources[type] = klass
  end

  def self.clear_registered
    @@data_sources = {}
    @@contexts = {}

    register_data_source("category", CategoryHashtagDataSource)
    register_data_source("tag", TagHashtagDataSource)

    register_type_in_context("category", "topic-composer", 100)
    register_type_in_context("tag", "topic-composer", 50)
  end

  def self.register_type_in_context(param, context, priority)
    @@contexts[context] = @@contexts[context] || {}
    @@contexts[context][param] = priority
  end

  def self.ordered_types_for_context(context)
    return [] if @@contexts[context].blank?
    @@contexts[context].sort_by { |param, priority| priority }.reverse.map(&:first)
  end

  def self.contexts_with_ordered_types
    final = {}
    @@contexts.keys.each do |context|
      final[context] = ordered_types_for_context(context)
    end
    final
  end

  clear_registered

  class HashtagItem
    # The text to display in the UI autocomplete menu for the item.
    attr_accessor :text

    # Canonical slug for the item. Different from the ref, which can
    # have the type as a suffix to distinguish between conflicts.
    attr_accessor :slug

    # The icon to display in the UI autocomplete menu for the item.
    attr_accessor :icon

    # Distinguishes between different entities e.g. tag, category.
    attr_accessor :type

    # Inserted into the textbox when an autocomplete item is selected,
    # and must be unique so it can be used for lookups via the #lookup
    # method above.
    attr_accessor :ref

    # The URL for the resource that is represented by the autocomplete
    # item, used for the cooked hashtags, e.g. /c/2/staff
    attr_accessor :url
  end

  def initialize(guardian)
    @guardian = guardian
  end

  def lookup(slugs, types_in_priority_order)
    raise Discourse::InvalidParameters.new(:slugs) if !slugs.is_a?(Array)
    raise Discourse::InvalidParameters.new(:order) if !types_in_priority_order.is_a?(Array)

    types_in_priority_order =
      types_in_priority_order.select { |type| @@data_sources.keys.include?(type) }
    lookup_results = Hash[types_in_priority_order.collect { |type| [type.to_sym, []] }]
    limited_slugs = slugs[0..HashtagAutocompleteService::HASHTAGS_PER_REQUEST]

    slugs_without_suffixes = limited_slugs.reject do |slug|
      @@data_sources.keys.any? do |type|
        slug.ends_with?("::#{type}")
      end
    end

    # for all the slugs without a suffix, we need to lookup in order, falling
    # back to the next type if no results are returned for a slug for the current
    # type. this way slugs without suffix make sense in context, e.g. in the topic
    # composer we want a slug without a suffix to be a category first, tag second
    types_in_priority_order.each do |type|
      result = @@data_sources[type].lookup(guardian, slugs_without_suffixes)
      lookup_results[type.to_sym] = lookup_results[type.to_sym].concat(result)
      slugs_without_suffixes = slugs_without_suffixes - result.map(&:slug)
      break if slugs_without_suffixes.empty?
    end

    # we then look up the remaining slugs based on their type, stripping out
    # the type suffix first since it will not match the actual slug
    slugs_with_suffixes = (limited_slugs - slugs_without_suffixes)
    types_in_priority_order.each do |type|
      typed_slugs = slugs_with_suffixes.select do |slug|
        slug.ends_with?("::#{type}")
      end.map do |slug|
        slug.gsub("::#{type}", "")
      end
      next if typed_slugs.empty?
      result = @@data_sources[type].lookup(guardian, typed_slugs)
      lookup_results[type.to_sym] = lookup_results[type.to_sym].concat(result)
    end

    lookup_results
  end

  def search(term, types_in_priority_order, limit: 5)
    raise Discourse::InvalidParameters.new(:order) if !types_in_priority_order.is_a?(Array)
    limit = [limit, SEARCH_MAX_LIMIT].min

    results = []
    slugs_by_type = {}
    term = term.downcase
    types_in_priority_order =
      types_in_priority_order.select { |type| @@data_sources.keys.include?(type) }

    types_in_priority_order.each do |type|
      data = @@data_sources[type].search(guardian, term, limit - results.length)
      next if data.empty?

      all_data_items_valid = data.all? do |item|
        item.kind_of?(HashtagItem) && item.slug.present? && item.text.present?
      end
      next if !all_data_items_valid

      data.each do |item|
        item.type = type
        item.ref = item.ref || item.slug
      end
      data.sort_by! { |item| item.text.downcase }
      slugs_by_type[type] = data.map(&:slug)

      results.concat(data)

      break if results.length >= limit
    end

    # Any items that are _not_ the top-ranked type (which could possibly not be
    # the same as the first item in the types_in_priority_order if there was
    # no data for that type) that have conflicting slugs with other items for
    # other types need to have a ::type suffix added to their ref.
    #
    # This will be used for the lookup method above if one of these items is
    # chosen in the UI, otherwise there is no way to determine whether a hashtag is
    # for a category or a tag etc.
    #
    # For example, if there is a category with the slug #general and a tag
    # with the slug #general, then the tag will have its ref changed to #general::tag
    top_ranked_type = slugs_by_type.keys.first
    results.each do |hashtag_item|
      next if hashtag_item.type == top_ranked_type

      other_slugs = results.reject { |r| r.type === hashtag_item.type }.map(&:slug)
      if other_slugs.include?(hashtag_item.slug)
        hashtag_item.ref = "#{hashtag_item.slug}::#{hashtag_item.type}"
      end
    end

    results.take(limit)
  end

  # TODO (martin) Remove this once plugins are not relying on the old lookup
  # behavior via HashtagsController
  def lookup_old(slugs)
    raise Discourse::InvalidParameters.new(:slugs) if !slugs.is_a?(Array)

    all_slugs = []
    tag_slugs = []

    slugs[0..HashtagAutocompleteService::HASHTAGS_PER_REQUEST].each do |slug|
      if slug.end_with?(PrettyText::Helpers::TAG_HASHTAG_POSTFIX)
        tag_slugs << slug.chomp(PrettyText::Helpers::TAG_HASHTAG_POSTFIX)
      else
        all_slugs << slug
      end
    end

    # Try to resolve hashtags as categories first
    category_slugs_and_ids =
      all_slugs.map { |slug| [slug, Category.query_from_hashtag_slug(slug)&.id] }.to_h
    category_ids_and_urls =
      Category
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
      DiscourseTagging
        .filter_visible(Tag.where_name(tag_slugs), guardian)
        .each { |tag| tag_hashtags[tag.name] = tag.full_url }
    end

    { categories: categories_hashtags, tags: tag_hashtags }
  end
end
