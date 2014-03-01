class Search

  class SearchResult
    class TextHelper
      extend ActionView::Helpers::TextHelper
    end

    attr_accessor :type, :id, :topic_id

    # Category attributes
    attr_accessor :color, :text_color

    # User attributes
    attr_accessor :avatar_template

    def initialize(row)
      row.symbolize_keys!
      @type = row[:type].to_sym
      @url, @id, @title, @topic_id = row[:url], row[:id], row[:title], row[:topic_id]
    end

    def as_json(options = nil)
      json = {id: @id, title: @title, url: @url}
      json[:avatar_template] = @avatar_template if @avatar_template.present?
      json[:color] = @color if @color.present?
      json[:text_color] = @text_color if @text_color.present?
      json
    end

    def self.from_category(c)
      SearchResult.new(type: :category, id: c.id, title: c.name, url: c.url).tap do |r|
        r.color = c.color
        r.text_color = c.text_color
      end
    end

    def self.from_user(u)
      SearchResult.new(type: :user, id: u.username_lower, title: u.username, url: "/users/#{u.username_lower}").tap do |r|
        r.avatar_template = u.avatar_template
      end
    end

    def self.from_topic(t, custom_title=nil)
      SearchResult.new(type: :topic, topic_id: t.id, id: t.id, title: custom_title || t.title, url: t.relative_url)
    end

    def self.from_post(p, context, term)
      custom_title =
        if context && context.id == p.topic_id
          # TODO: rewrite this
          # 1. convert markdown to text
          # 2. grab full words
          excerpt = TextHelper.excerpt(p.raw, term.split(/\s+/)[0], radius: 30)
          excerpt = TextHelper.truncate(p.raw, length: 50) if excerpt.blank?
          I18n.t("search.within_post",
                 post_number: p.post_number,
                 username: p.user && p.user.username,
                 excerpt: excerpt
                )
        end

      if p.post_number == 1
        # we want the topic link when it's the OP
        SearchResult.from_topic(p.topic, custom_title)
      elsif context && context.id == p.topic_id
        SearchResult.new(type: :topic, topic_id: p.topic_id, id: "_#{p.id}", title: custom_title, url: p.url)
      else
        SearchResult.new(type: :topic, topic_id: p.topic_id, id: p.topic.id, title: p.topic.title, url: p.url)
      end
    end

  end

end
