# frozen_string_literal: true

class HashtagsController < ApplicationController
  requires_login

  HASHTAGS_PER_REQUEST = 20

  def show
    if !params[:slugs].is_a?(Array)
      raise Discourse::InvalidParameters.new(:slugs)
    end

    all_slugs = []
    tag_slugs = []

    params[:slugs][0..HASHTAGS_PER_REQUEST].each do |slug|
      if slug.end_with?(PrettyText::Helpers::TAG_HASHTAG_POSTFIX)
        tag_slugs << slug.chomp(PrettyText::Helpers::TAG_HASHTAG_POSTFIX)
      else
        all_slugs << slug
      end
    end

    # Try to resolve hashtags as categories first
    category_slugs_and_ids =
      all_slugs
        .map { |slug| [slug, Category.query_from_hashtag_slug(slug)&.id] }
        .to_h
    category_ids_and_urls =
      Category
        .secured(guardian)
        .select(
          :id,
          :slug,
          :parent_category_id
        ) # fields required for generating category URL
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

    render json: { categories: categories_hashtags, tags: tag_hashtags }
  end
end
