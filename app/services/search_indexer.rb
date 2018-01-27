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

  def self.update_index(table, id, *raw_entries)
    raw_data = Search.prepare_data(raw_entries.join(' '), :index)

    table_name = "#{table}_search_data"
    foreign_key = "#{table}_id"
    stemmer = stemmer_from_table(table)

    indexable_entries = raw_entries.collect{|raw_entry| prepare_entry_for_indexing(raw_entry)}

    # Would be nice to use AR here but not sure how to execut Postgres functions
    # when inserting data like this.
    statement_params = params_for_update_index_statement(id, indexable_entries, raw_data)
    ts_vector = build_ts_vector(stemmer, indexable_entries)

    rows = Post.exec_sql_row_count("UPDATE #{table_name}
                                   SET
                                      raw_data = :raw_data,
                                      locale = :locale,
                                      search_data = #{ts_vector},
                                      version = :version
                                   WHERE #{foreign_key} = :id",
                                    statement_params)
    if rows == 0
      Post.exec_sql("INSERT INTO #{table_name}
                    (#{foreign_key}, search_data, locale, raw_data, version)
                    VALUES (:id, #{ts_vector}, :locale, :raw_data, :version)",
                                      statement_params)
    end

    rescue
    # don't allow concurrency to mess up saving a post
  end

  # for user login and name use "simple" lowercase stemmer
  def self.stemmer_from_table(table)
    table == "user" ? "simple" : Search.ts_config
  end

  # insert some extra words for I.am.a.word so "word" is tokenized
  # I.am.a.word becomes I.am.a.word am a word
  def self.prepare_entry_for_indexing(raw_data)
    raw_data.gsub(/[^[:space:]]*[\.]+[^[:space:]]*/) do |with_dot|
      split = with_dot.split(".")
      if split.length > 1
        with_dot + (" " << split[1..-1].join(" "))
      else
        with_dot
      end
    end
  end

  def self.params_for_update_index_statement(id, indexable_entries, raw_data)
    statement_params = {
      raw_data: raw_data,
      id: id,
      locale: SiteSetting.default_locale,
      version: Search::INDEX_VERSION
    }

    indexable_entries.each.with_index do |indexable_entry, index|
      statement_params[update_index_param_name_for(index)] = indexable_entry
    end

    statement_params
  end

  def self.update_index_param_name_for(index)
    "indexable_fragment_#{index}".to_sym
  end

  def self.build_ts_vector(stemmer, indexable_entries)
    raise ArgumentError, "The max number of entries to index is 4 to match the number of weights supported by PostgreSQL (A, B, C, D)" unless indexable_entries.length.between?(1, 4)

    ts_vectors = indexable_entries.collect.with_index do |_, index|
      "TO_TSVECTOR('#{stemmer}', :#{update_index_param_name_for(index)})"
    end

    if indexable_entries.length == 1
      # index without weights
      ts_vectors.first
    else
      weight_letters = ('A'..'D').to_a
      ts_vectors.collect.with_index do |ts_vector, index|
        weight_letter = weight_letters[index]
        "setweight(#{ts_vector}, '#{weight_letter}')"
      end.join(" || ")
    end
  end

  def self.update_topics_index(topic_id, title, cooked)
    indexable_title = title.dup
    indexable_cooked = scrub_html_for_search(cooked)[0...Topic::MAX_SIMILAR_BODY_LENGTH]
    update_index('topic', topic_id, indexable_title, indexable_cooked)
  end

  def self.update_posts_index(post_id, cooked, title, category)
    search_data = scrub_html_for_search(cooked) << " " << title.dup.force_encoding('UTF-8')
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

  def self.update_tags_index(tag_id, name)
    update_index('tag', tag_id, name)
  end

  def self.index(obj, force: false)
    return if @disabled

    if obj.class == Post && (obj.saved_change_to_cooked? || force)
      if obj.topic
        category_name = obj.topic.category.name if obj.topic.category
        SearchIndexer.update_posts_index(obj.id, obj.cooked, obj.topic.title, category_name)
        SearchIndexer.update_topics_index(obj.topic_id, obj.topic.title, obj.cooked) if obj.is_first_post?
      else
        Rails.logger.warn("Orphan post skipped in search_indexer, topic_id: #{obj.topic_id} post_id: #{obj.id} raw: #{obj.raw}")
      end
    end

    if obj.class == User && (obj.saved_change_to_username? || obj.saved_change_to_name? || force)
      SearchIndexer.update_users_index(obj.id, obj.username_lower || '', obj.name ? obj.name.downcase : '')
    end

    if obj.class == Topic && (obj.saved_change_to_title? || force)
      if obj.posts
        post = obj.posts.find_by(post_number: 1)
        if post
          category_name = obj.category.name if obj.category
          SearchIndexer.update_posts_index(post.id, post.cooked, obj.title, category_name)
          SearchIndexer.update_topics_index(obj.id, obj.title, post.cooked)
        end
      end
    end

    if obj.class == Category && (obj.saved_change_to_name? || force)
      SearchIndexer.update_categories_index(obj.id, obj.name)
    end

    if obj.class == Tag && (obj.saved_change_to_name? || force)
      SearchIndexer.update_tags_index(obj.id, obj.name)
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
    end

    def characters(string)
      scrubbed << " "
      scrubbed << string
      scrubbed << " "
    end
  end
end
