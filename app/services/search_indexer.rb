# frozen_string_literal: true

class SearchIndexer
  INDEX_VERSION = 3
  REINDEX_VERSION = 0

  def self.disable
    @disabled = true
  end

  def self.enable
    @disabled = false
  end

  def self.scrub_html_for_search(html, strip_diacritics: SiteSetting.search_ignore_accents)
    HtmlScrubber.scrub(html, strip_diacritics: strip_diacritics)
  end

  def self.inject_extra_terms(raw)
    # insert some extra words for I.am.a.word so "word" is tokenized
    # I.am.a.word becomes I.am.a.word am a word
    raw.gsub(/[^[:space:]]*[\.]+[^[:space:]]*/) do |with_dot|

      split = with_dot.split(/https?:\/\/|[?:;,.\/]/)

      if split.length > 1
        with_dot + ((+" ") << split[1..-1].reject { |x| x.blank? }.join(" "))
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
      version: INDEX_VERSION
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
    update_index(table: 'tag', id: tag_id, raw_data: [name.downcase])
  end

  def self.queue_post_reindex(topic_id)
    return if @disabled

    DB.exec(<<~SQL, topic_id: topic_id, version: REINDEX_VERSION)
      UPDATE post_search_data
      SET version = :version
      FROM posts
      WHERE post_search_data.post_id = posts.id
      AND posts.topic_id = :topic_id
    SQL
  end

  def self.index(obj, force: false)
    return if @disabled

    category_name = nil
    tag_names = nil
    topic = nil

    if Topic === obj
      topic = obj
    elsif Post === obj
      topic = obj.topic
    end

    category_name = topic.category&.name if topic
    if topic
      tags = topic.tags.select(:id, :name)
      unless tags.empty?
        tag_names = (tags.map(&:name) + Tag.where(target_tag_id: tags.map(&:id)).pluck(:name)).join(' ')
      end
    end

    if Post === obj && obj.raw.present? &&
       (
         obj.saved_change_to_cooked? ||
         obj.saved_change_to_topic_id? ||
         force
       )

      if topic
        SearchIndexer.update_posts_index(obj.id, topic.title, category_name, tag_names, obj.cooked)
        SearchIndexer.update_topics_index(topic.id, topic.title, obj.cooked) if obj.is_first_post?
      end
    end

    if User === obj && (obj.saved_change_to_username? || obj.saved_change_to_name? || force)
      SearchIndexer.update_users_index(obj.id, obj.username_lower || '', obj.name ? obj.name.downcase : '')
    end

    if Topic === obj && (obj.saved_change_to_title? || force)
      if obj.posts
        if post = obj.posts.find_by(post_number: 1)
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

    def initialize(strip_diacritics: false)
      @scrubbed = +""
      @strip_diacritics = strip_diacritics
    end

    def self.scrub(html, strip_diacritics: false)
      return +"" if html.blank?

      document = Nokogiri::HTML("<div>#{html}</div>", nil, Encoding::UTF_8.to_s)

      nodes = document.css(
        "div.#{CookedPostProcessor::LIGHTBOX_WRAPPER_CSS_CLASS}"
      )

      if nodes.present?
        nodes.each do |node|
          node.traverse do |child_node|
            next if child_node == node

            if %w{a img}.exclude?(child_node.name)
              child_node.remove
            elsif child_node.name == "a"
              ATTRIBUTES.each do |attribute|
                child_node.remove_attribute(attribute)
              end
            end
          end
        end
      end

      document.css("img[class='emoji']").each do |node|
        node.remove_attribute("alt")
      end

      document.css("a[href]").each do |node|
        if node["href"] == node.text || MENTION_CLASSES.include?(node["class"])
          node.remove_attribute("href")
        end
      end

      me = new(strip_diacritics: strip_diacritics)
      Nokogiri::HTML::SAX::Parser.new(me).parse(document.to_html)
      me.scrubbed.squish
    end

    MENTION_CLASSES ||= %w{mention mention-group}
    ATTRIBUTES ||= %w{alt title href data-youtube-title}

    def start_element(_name, attributes = [])
      attributes = Hash[*attributes.flatten]

      ATTRIBUTES.each do |attribute_name|
        if attributes[attribute_name].present? &&
          !(
            attribute_name == "href" &&
            UrlHelper.is_local(attributes[attribute_name])
          )

          characters(attributes[attribute_name])
        end
      end
    end

    def characters(str)
      str = Search.strip_diacritics(str) if @strip_diacritics
      scrubbed << " #{str} "
    end
  end
end
