require 'sanitize'

class Search

  class GroupedSearchResults
    include ActiveModel::Serialization

    class TextHelper
      extend ActionView::Helpers::TextHelper
    end

    attr_reader :type_filter,
                :posts, :categories, :users,
                :more_posts, :more_categories, :more_users,
                :term, :search_context, :include_blurbs

    def initialize(type_filter, term, search_context, include_blurbs)
      @type_filter = type_filter
      @term = term
      @search_context = search_context
      @include_blurbs = include_blurbs
      @posts = []
      @categories = []
      @users = []
    end

    def blurb(post)
      GroupedSearchResults.blurb_for(post.cooked, @term)
    end

    def add(object)
      type = object.class.to_s.downcase.pluralize

      if !@type_filter.present? && send(type).length == Search.per_facet
        instance_variable_set("@more_#{type}".to_sym, true)
      else
        (send type) << object
      end
    end


    def self.blurb_for(cooked, term=nil)
      cooked = SearchObserver::HtmlScrubber.scrub(cooked).squish

      blurb = nil
      if term
        terms = term.split(/\s+/)
        blurb = TextHelper.excerpt(cooked, terms.first, radius: 100)
      end
      blurb = TextHelper.truncate(cooked, length: 200) if blurb.blank?
      Sanitize.clean(blurb)
    end
  end

end
