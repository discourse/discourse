require_dependency 'search'

class SearchObserver < ActiveRecord::Observer
  observe :topic, :post, :user, :category

  def self.scrub_html_for_search(html)
    HtmlScrubber.scrub(html)
  end

  def self.update_index(table, id, search_data)
    table_name = "#{table}_search_data"
    foreign_key = "#{table}_id"

    # for user login and name use "simple" lowercase stemmer
    stemmer = table == "user" ? "simple" : Search.long_locale

    # Would be nice to use AR here but not sure how to execut Postgres functions
    # when inserting data like this.
    rows = Post.exec_sql_row_count("UPDATE #{table_name} SET search_data = TO_TSVECTOR('#{stemmer}', ?) WHERE #{foreign_key} = ?", search_data, id)
    if rows == 0
      Post.exec_sql("INSERT INTO #{table_name} (#{foreign_key}, search_data) VALUES (?, TO_TSVECTOR('#{stemmer}', ?))", id, search_data)
    end
  rescue
    # don't allow concurrency to mess up saving a post
  end

  def self.update_posts_index(post_id, cooked, title, category)
    search_data = scrub_html_for_search(cooked) << " " << title
    search_data << " " << category if category
    update_index('post', post_id, search_data)
  end

  def self.update_users_index(user_id, username, name)
    search_data = username.dup << " " << (name || "")
    update_index('user', user_id, search_data)
  end

  def self.update_categories_index(category_id, name)
    update_index('category', category_id, name)
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

