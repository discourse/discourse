# frozen_string_literal: true
require_dependency 'search'

class SearchIndexer

  def self.disable
    @disabled = true
  end

  def self.enable
    @disabled = false
  end

  def self.scrub_html_for_search(html)
    HtmlScrubber.scrub(html)
  end

  def self.inject_extra_terms(raw)
    # insert some extra words for I.am.a.word so "word" is tokenized
    # I.am.a.word becomes I.am.a.word am a word
    raw.gsub(/[^[:space:]]*[\.]+[^[:space:]]*/) do |with_dot|
      split = with_dot.split(".")
      if split.length > 1
        with_dot + ((+" ") << split[1..-1].join(" "))
      else
        with_dot
      end
    end
  end

  def self.update_index(table: , id: , raw_data:)
    search_data = raw_data.map do |data|
      inject_extra_terms(Search.prepare_data(data || "", :index))
    end

    table_name = "#{table}_search_data"
    foreign_key = "#{table}_id"

    # for user login and name use "simple" lowercase stemmer
    stemmer = table == "user" ? "simple" : Search.ts_config

    ranked_index = <<~SQL
      setweight(to_tsvector('#{stemmer}', coalesce(:a,'')), 'A') ||
      setweight(to_tsvector('#{stemmer}', coalesce(:b,'')), 'B') ||
      setweight(to_tsvector('#{stemmer}', coalesce(:c,'')), 'C') ||
      setweight(to_tsvector('#{stemmer}', coalesce(:d,'')), 'D')
    SQL

    indexed_data = search_data.select { |d| d.length > 0 }.join(' ')

    params = {
      a: search_data[0],
      b: search_data[1],
      c: search_data[2],
      d: search_data[3],
      raw_data: indexed_data,
      id: id,
      locale: SiteSetting.default_locale,
      version: Search::INDEX_VERSION
    }

    # Would be nice to use AR here but not sure how to execut Postgres functions
    # when inserting data like this.
    rows = DB.exec(<<~SQL, params)
       UPDATE #{table_name}
       SET
          raw_data = :raw_data,
          locale = :locale,
          search_data = #{ranked_index},
          version = :version
       WHERE #{foreign_key} = :id
    SQL

    if rows == 0
      DB.exec(<<~SQL, params)
        INSERT INTO #{table_name}
        (#{foreign_key}, search_data, locale, raw_data, version)
        VALUES (:id, #{ranked_index}, :locale, :raw_data, :version)
      SQL
    end
  rescue
    # TODO is there any way we can safely avoid this?
    # best way is probably pushing search indexer into a dedicated process so it no longer happens on save
    # instead in the post processor
  end

  def self.update_topics_index(topic_id, title, cooked)
    scrubbed_cooked = scrub_html_for_search(cooked)[0...Topic::MAX_SIMILAR_BODY_LENGTH]

    # a bit inconsitent that we use title as A and body as B when in
    # the post index body is C
    update_index(table: 'topic', id: topic_id, raw_data: [title, scrubbed_cooked])
  end

  def self.update_posts_index(post_id, title, category, tags, cooked)
    update_index(table: 'post', id: post_id, raw_data: [title, category, tags, scrub_html_for_search(cooked)])
  end

  def self.update_users_index(user_id, username, name)
    update_index(table: 'user', id: user_id, raw_data: [username, name])
  end

  def self.update_categories_index(category_id, name)
    update_index(table: 'category', id: category_id, raw_data: [name])
  end

  def self.update_tags_index(tag_id, name)
    update_index(table: 'tag', id: tag_id, raw_data: [name])
  end

  def self.queue_post_reindex(topic_id)
    return if @disabled

    DB.exec(<<~SQL, topic_id: topic_id)
      UPDATE post_search_data
      SET version = 0
      WHERE post_id IN (SELECT id FROM posts WHERE topic_id = :topic_id)
    SQL
  end

  def self.index(obj, force: false)
    return if @disabled

    category_name, tag_names = nil
    topic = nil

    if Topic === obj
      topic = obj
    elsif Post === obj
      topic = obj.topic
    end

    category_name = topic.category&.name if topic
    tag_names = topic.tags.pluck(:name).join(' ') if topic

    if Post === obj && (obj.saved_change_to_cooked? || force)
      if topic
        SearchIndexer.update_posts_index(obj.id, topic.title, category_name, tag_names, obj.cooked)
        SearchIndexer.update_topics_index(topic.id, topic.title, obj.cooked) if obj.is_first_post?
      else
        Rails.logger.warn("Orphan post skipped in search_indexer, topic_id: #{obj.topic_id} post_id: #{obj.id} raw: #{obj.raw}")
      end
    end

    if User === obj && (obj.saved_change_to_username? || obj.saved_change_to_name? || force)
      SearchIndexer.update_users_index(obj.id, obj.username_lower || '', obj.name ? obj.name.downcase : '')
    end

    if Topic === obj && (obj.saved_change_to_title? || force)
      if obj.posts
        post = obj.posts.find_by(post_number: 1)
        if post
          SearchIndexer.update_posts_index(post.id, obj.title, category_name, tag_names, post.cooked)
          SearchIndexer.update_topics_index(obj.id, obj.title, post.cooked)
        end
      end
    end

    if Category === obj && (obj.saved_change_to_name? || force)
      SearchIndexer.update_categories_index(obj.id, obj.name)
    end

    if Tag === obj && (obj.saved_change_to_name? || force)
      SearchIndexer.update_tags_index(obj.id, obj.name)
    end
  end

  class HtmlScrubber < Nokogiri::XML::SAX::Document
    attr_reader :scrubbed

    def initialize
      @scrubbed = +""
    end

    def self.scrub(html)
      me = new
      parser = Nokogiri::HTML::SAX::Parser.new(me)
      begin
        copy = +"<div>"
        copy << html unless html.nil?
        copy << "</div>"
        parser.parse(html) unless html.nil?
      end
      me.scrubbed
    end

    def start_element(name, attributes = [])
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
      if attributes["data-youtube-title"]
        scrubbed << " "
        scrubbed << attributes["data-youtube-title"]
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
