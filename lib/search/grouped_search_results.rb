# frozen_string_literal: true

require 'sanitize'

class Search

  class GroupedSearchResults
    include ActiveModel::Serialization

    class TextHelper
      extend ActionView::Helpers::TextHelper
    end

    attr_reader(
      :type_filter,
      :posts,
      :categories,
      :users,
      :tags,
      :groups,
      :more_posts,
      :more_categories,
      :more_users,
      :term,
      :search_context,
      :include_blurbs,
      :more_full_page_results,
      :error
    )

    attr_accessor :search_log_id

    def initialize(type_filter, term, search_context, include_blurbs, blurb_length)
      @type_filter = type_filter
      @term = term
      @search_context = search_context
      @include_blurbs = include_blurbs
      @blurb_length = blurb_length || 200
      @posts = []
      @categories = []
      @users = []
      @tags = []
      @groups = []
      @error = nil
    end

    def error=(error)
      @error = error
    end

    def find_user_data(guardian)
      if user = guardian.user
        topics = @posts.map(&:topic)
        topic_lookup = TopicUser.lookup_for(user, topics)
        topics.each { |ft| ft.user_data = topic_lookup[ft.id] }
      end
    end

    def blurb(post)
      GroupedSearchResults.blurb_for(post.cooked, @term, @blurb_length)
    end

    def add(object)
      type = object.class.to_s.downcase.pluralize

      if @type_filter.present? && public_send(type).length == Search.per_filter
        @more_full_page_results = true
      elsif !@type_filter.present? && public_send(type).length == Search.per_facet
        instance_variable_set("@more_#{type}".to_sym, true)
      else
        (self.public_send(type)) << object
      end
    end

    def self.blurb_for(cooked, term = nil, blurb_length = 200)
      blurb = nil
      cooked = SearchIndexer.scrub_html_for_search(cooked)

      urls = Set.new
      cooked.scan(URI.regexp(%w{http https})) { urls << $& }

      urls.each do |url|
        cooked.gsub!(url, I18n.t("search.video")) if url.match(/.(mov|mp4|webm|ogv)/)
        cooked.gsub!(url, I18n.t("search.audio")) if url.match(/.(mp3|ogg|wav|m4a)/)
      end

      if term
        terms = term.split(/\s+/)
        phrase = terms.first

        if phrase =~ Regexp.new(Search::PHRASE_MATCH_REGEXP_PATTERN)
          phrase = Regexp.last_match[1]
        end

        blurb = TextHelper.excerpt(cooked, phrase,
          radius: blurb_length / 2,
          seperator: " "
        )
      end

      blurb = TextHelper.truncate(cooked, length: blurb_length, seperator: " ") if blurb.blank?
      Sanitize.clean(blurb)
    end
  end

end
