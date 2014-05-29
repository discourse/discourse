class Search

  class SearchResult
    class TextHelper
      extend ActionView::Helpers::TextHelper
    end

    attr_accessor :type, :id, :topic_id, :blurb

    # Category attributes
    attr_accessor :color, :text_color

    # User attributes
    attr_accessor :avatar_template, :uploaded_avatar_id

    def initialize(row)
      row.symbolize_keys!
      @type = row[:type].to_sym
      @url, @id, @title, @topic_id, @blurb = row[:url], row[:id], row[:title], row[:topic_id], row[:blurb]
    end

    def as_json(options = nil)
      json = {id: @id, title: @title, url: @url}
      [ :avatar_template,
        :uploaded_avatar_id,
        :color,
        :text_color,
        :blurb
      ].each do |k|
        val = send(k)
        json[k] = val if val
      end
      json
    end

    def self.from_category(c)
      SearchResult.new(type: :category, id: c.id, title: c.name, url: c.url).tap do |r|
        r.color = c.color
        r.text_color = c.text_color
      end
    end

    def self.from_user(u)
      SearchResult.new(
        type: :user,
        id: u.username_lower,
        title: u.username,
        url: "/users/#{u.username_lower}").tap do |r|
          r.uploaded_avatar_id = u.uploaded_avatar_id
          r.avatar_template = u.avatar_template
      end
    end

    def self.from_topic(t, options = {})
      SearchResult.new(type: :topic, topic_id: t.id, id: t.id, title: options[:custom_title] || t.title, url: t.relative_url, blurb: options[:custom_blurb])
    end

    def self.from_post(p, context, term, include_blurbs=false)
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
      if include_blurbs
        #add a blurb from the post to the search results
        custom_blurb = TextHelper.excerpt(p.raw, term.split(/\s+/)[0], radius: 100)
        custom_blurb = TextHelper.truncate(p.raw, length: 200) if custom_blurb.blank?
      end
      if p.post_number == 1
        # we want the topic link when it's the OP
        SearchResult.from_topic(p.topic, {custom_title: custom_title, custom_blurb: custom_blurb})
      elsif context && context.id == p.topic_id
        SearchResult.new(type: :topic, topic_id: p.topic_id, id: "_#{p.id}", title: custom_title, url: p.url, blurb: custom_blurb)
      else
        SearchResult.new(type: :topic, topic_id: p.topic_id, id: p.topic.id, title: p.topic.title, url: p.url, blurb: custom_blurb)
      end
    end

  end

end
