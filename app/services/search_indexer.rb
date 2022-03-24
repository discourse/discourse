# frozen_string_literal: true

class SearchIndexer
  POST_INDEX_VERSION = 4
  MIN_POST_REINDEX_VERSION = 3
  TOPIC_INDEX_VERSION = 3
  CATEGORY_INDEX_VERSION = 3
  USER_INDEX_VERSION = 3
  TAG_INDEX_VERSION = 3
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

  def self.update_index(table: , id: , a_weight: nil, b_weight: nil, c_weight: nil, d_weight: nil)
    raw_data = [a_weight, b_weight, c_weight, d_weight]

    search_data = raw_data.map do |data|
      Search.prepare_data(data || "", :index)
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

    ranked_params = {
      a: search_data[0],
      b: search_data[1],
      c: search_data[2],
      d: search_data[3],
    }

    tsvector = DB.query_single("SELECT #{ranked_index}", ranked_params)[0]
    additional_lexemes = []

    tsvector.scan(/'(([a-zA-Z0-9]+\.)+[a-zA-Z0-9]+)'\:([\w+,]+)/).reduce(additional_lexemes) do |array, (lexeme, _, positions)|
      count = 0

      if lexeme !~ /^(\d+\.)?(\d+\.)*(\*|\d+)$/
        loop do
          count += 1
          break if count >= 10 # Safeguard here to prevent infinite loop when a term has many dots
          term, _, remaining = lexeme.partition(".")
          break if remaining.blank?
          array << "'#{remaining}':#{positions}"
          lexeme = remaining
        end
      end

      array
    end

    tsvector = "#{tsvector} #{additional_lexemes.join(' ')}"

    indexed_data =
      if table.to_s == "post"
        clean_post_raw_data!(ranked_params[:d])
      else
        search_data.select { |d| d.length > 0 }.join(' ')
      end

    params = {
      "raw_data" => indexed_data,
      "#{foreign_key}" => id,
      "locale" => SiteSetting.default_locale,
      "version" => const_get("#{table.upcase}_INDEX_VERSION"),
      "search_data" => tsvector,
    }

    yield params if block_given?
    table_name.camelize.constantize.upsert(params)
  rescue => e
    if Rails.env.test?
      raise
    else
      # TODO is there any way we can safely avoid this?
      # best way is probably pushing search indexer into a dedicated process so it no longer happens on save
      # instead in the post processor
      Discourse.warn_exception(
        e,
        message: "Unexpected error while indexing #{table} for search",
        env: { id: id }
      )
    end
  end

  def self.update_topics_index(topic_id, title, cooked)
    # a bit inconsistent that we use title as A and body as B when in
    # the post index body is D
    update_index(
      table: 'topic',
      id: topic_id,
      a_weight: title,
      b_weight: scrub_html_for_search(cooked)[0...Topic::MAX_SIMILAR_BODY_LENGTH]
    )
  end

  def self.update_posts_index(post_id:, topic_title:, category_name:, topic_tags:, cooked:, private_message:)
    update_index(
      table: 'post',
      id: post_id,
      a_weight: topic_title,
      b_weight: category_name,
      c_weight: topic_tags,
      # The tsvector resulted from parsing a string can be double the size of
      # the original string. Since there is no way to estimate the length of
      # the expected tsvector, we limit the input to ~50% of the maximum
      # length of a tsvector (1_048_576 bytes).
      d_weight: scrub_html_for_search(cooked)[0..600_000]
    ) do |params|
      params["private_message"] = private_message
    end
  end

  def self.update_users_index(user_id, username, name, custom_fields)
    update_index(
      table: 'user',
      id: user_id,
      a_weight: username,
      b_weight: name,
      c_weight: custom_fields
    )
  end

  def self.update_categories_index(category_id, name)
    update_index(
      table: 'category',
      id: category_id,
      a_weight: name
    )
  end

  def self.update_tags_index(tag_id, name)
    update_index(
      table: 'tag',
      id: tag_id,
      a_weight: name.downcase
    )
  end

  def self.queue_category_posts_reindex(category_id)
    return if @disabled

    DB.exec(<<~SQL, category_id: category_id, version: REINDEX_VERSION)
      UPDATE post_search_data
      SET version = :version
      FROM posts
      INNER JOIN topics ON posts.topic_id = topics.id
      INNER JOIN categories ON topics.category_id = categories.id
      WHERE post_search_data.post_id = posts.id
      AND categories.id = :category_id
    SQL
  end

  def self.queue_users_reindex(user_ids)
    return if @disabled

    DB.exec(<<~SQL, user_ids: user_ids, version: REINDEX_VERSION)
      UPDATE user_search_data
      SET version = :version
      WHERE user_search_data.user_id IN (:user_ids)
    SQL
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
      tags = topic.tags.select(:id, :name).to_a

      if tags.present?
        tag_names = (tags.map(&:name) + Tag.where(target_tag_id: tags.map(&:id)).pluck(:name)).join(' ')
      end
    end

    if Post === obj && obj.raw.present? &&
       (
         force ||
         obj.saved_change_to_cooked? ||
         obj.saved_change_to_topic_id?
       )

      if topic
        SearchIndexer.update_posts_index(
          post_id: obj.id,
          topic_title: topic.title,
          category_name: category_name,
          topic_tags: tag_names,
          cooked: obj.cooked,
          private_message: topic.private_message?
        )

        SearchIndexer.update_topics_index(topic.id, topic.title, obj.cooked) if obj.is_first_post?
      end
    end

    if User === obj && (obj.saved_change_to_username? || obj.saved_change_to_name? || force)
      SearchIndexer.update_users_index(obj.id,
                                       obj.username_lower || '',
                                       obj.name ? obj.name.downcase : '',
                                       obj.user_custom_fields.searchable.map(&:value).join(" "))
    end

    if Topic === obj && (obj.saved_change_to_title? || force)
      if obj.posts
        if post = obj.posts.find_by(post_number: 1)
          SearchIndexer.update_posts_index(
            post_id: post.id,
            topic_title: obj.title,
            category_name: category_name,
            topic_tags: tag_names,
            cooked: post.cooked,
            private_message: obj.private_message?
          )

          SearchIndexer.update_topics_index(obj.id, obj.title, post.cooked)
        end
      end
    end

    if Category === obj && (obj.saved_change_to_name? || force)
      SearchIndexer.queue_category_posts_reindex(obj.id)
      SearchIndexer.update_categories_index(obj.id, obj.name)
    end

    if Tag === obj && (obj.saved_change_to_name? || force)
      SearchIndexer.update_tags_index(obj.id, obj.name)
    end
  end

  def self.clean_post_raw_data!(raw_data)
    urls = Set.new
    raw_data.scan(Discourse::Utils::URI_REGEXP) { urls << $& }

    urls.each do |url|
      begin
        case File.extname(URI(url).path || "")
        when Oneboxer::VIDEO_REGEX
          raw_data.gsub!(url, I18n.t("search.video"))
        when Oneboxer::AUDIO_REGEX
          raw_data.gsub!(url, I18n.t("search.audio"))
        end
      rescue URI::InvalidURIError
      end
    end

    raw_data
  end
  private_class_method :clean_post_raw_data!

  class HtmlScrubber < Nokogiri::XML::SAX::Document

    attr_reader :scrubbed

    def initialize(strip_diacritics: false)
      @scrubbed = +""
      @strip_diacritics = strip_diacritics
    end

    def self.scrub(html, strip_diacritics: false)
      return +"" if html.blank?

      begin
        document = Nokogiri::HTML5("<div>#{html}</div>", nil, Encoding::UTF_8.to_s)
      rescue ArgumentError
        return +""
      end

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

      document.css("img.emoji").each do |node|
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
