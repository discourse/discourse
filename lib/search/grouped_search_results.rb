require 'sanitize'

class Search

  class GroupedSearchResults

    include ActiveModel::Serialization

    class TextHelper
      extend ActionView::Helpers::TextHelper
      def self.sanitize(text)
        # we run through sanitize at the end so it does not matter
        text
      end
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
      cooked = SearchObserver::HtmlScrubber.scrub(post.cooked).squish
      terms = @term.split(/\s+/)
      blurb = TextHelper.excerpt(cooked, terms.first, radius: 100)

      # TODO highlight term
      # terms.each do |term|
      #   blurb = TextHelper.highlight(blurb, term)
      # end

      blurb = TextHelper.truncate(cooked, length: 200) if blurb.blank?

      Sanitize.clean(blurb)
    end

    def add(object)
      type = object.class.to_s.downcase.pluralize

      if !@type_filter.present? && send(type).length == Search.per_facet
        instance_variable_set("@more_#{type}".to_sym, true)
      else
        (send type) << object
      end
    end

  end

end
