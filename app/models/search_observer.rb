class SearchObserver < ActiveRecord::Observer
  observe :topic, :post, :user, :category

  def self.scrub_html_for_search(html)
    HtmlScrubber.scrub(html)
  end

  def self.update_index(table, id, idx)
    Post.exec_sql("delete from #{table} where id = ?", id)
    sql = "insert into #{table} (id, search_data) values (?, to_tsvector('english', ?))"
    begin
      Post.exec_sql(sql, id, idx)
    rescue
      # don't allow concurrency to mess up saving a post
    end
  end

  def self.update_posts_index(post_id, cooked, title, category)
    idx = scrub_html_for_search(cooked)
    idx << " " << title
    idx << " " << category if category
    update_index('posts_search', post_id, idx)
  end

  def self.update_users_index(user_id, username, name)
    idx = username.dup
    idx << " " << (name || "")

    update_index('users_search', user_id, idx)
  end

  def self.update_categories_index(category_id, name)
    update_index('categories_search', category_id, name)
  end

  def after_save(obj)
    if obj.class == Post && obj.cooked_changed?
      category_name = obj.topic.category.name if obj.topic.category
      SearchObserver.update_posts_index(obj.id, obj.cooked, obj.topic.title, category_name)
    end
    if obj.class == User && (obj.username_changed? || obj.name_changed?)
      SearchObserver.update_users_index(obj.id, obj.username, obj.name)
    end

    if obj.class == Topic && obj.title_changed?
      if obj.posts
        post = obj.posts.where(post_number: 1).first
        if post
          category_name = obj.category.name if obj.category
          SearchObserver.update_posts_index(post.id, post.cooked, obj.title, category_name)
        end
      end
    end

    if obj.class == Category && obj.name_changed?
      SearchObserver.update_categories_index(obj.id, obj.name)
    end
  end


  class HtmlScrubber < Nokogiri::XML::SAX::Document
    attr_reader :scrubbed

    def initialize
      @scrubbed = ""
    end

    def self.scrub(html)
      me = new
      parser = Nokogiri::HTML::SAX::Parser.new(me)
      begin
        copy = "<div>"
        copy << html unless html.nil?
        copy << "</div>"
        parser.parse(html) unless html.nil?
      end
      me.scrubbed
    end

    def start_element(name, attributes=[])
      attributes = Hash[*attributes.flatten]
      if attributes["alt"]
        scrubbed << " "
        scrubbed << attributes["alt"]
        scrubbed << " "
      end
      if attributes["title"]
        scrubbed << " "
        scrubbed << attributes["title"]
        scrubbed << " "
      end
    end

    def characters(string)
      scrubbed << " "
      scrubbed << string
      scrubbed << " "
    end
  end
end

