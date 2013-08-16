class Search

  class SearchResult
    attr_accessor :type, :id

    # Category attributes
    attr_accessor :color, :text_color

    # User attributes
    attr_accessor :avatar_template

    def initialize(row)
      row.symbolize_keys!
      @type = row[:type].to_sym
      @url, @id, @title = row[:url], row[:id], row[:title]
    end

    def as_json
      json = {id: @id, title: @title, url: @url}
      json[:avatar_template] = @avatar_template if @avatar_template.present?
      json[:color] = @color if @color.present?
      json[:text_color] = @text_color if @text_color.present?
      json
    end

    def self.from_category(c)
      SearchResult.new(type: :category, id: c.id, title: c.name, url: "/category/#{c.slug}").tap do |r|
        r.color = c.color
        r.text_color = c.text_color
      end
    end

    def self.from_user(u)
      SearchResult.new(type: :user, id: u.username_lower, title: u.username, url: "/users/#{u.username_lower}").tap do |r|
        r.avatar_template = u.avatar_template
      end
    end

    def self.from_topic(t)
      SearchResult.new(type: :topic, id: t.id, title: t.title, url: t.relative_url)
    end

    def self.from_post(p)
      if p.post_number == 1
        # we want the topic link when it's the OP
        SearchResult.from_topic(p.topic)
      else
        SearchResult.new(type: :topic, id: p.topic.id, title: p.topic.title, url: p.url)
      end
    end

  end

end
