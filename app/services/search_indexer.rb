# frozen_string_literal: true

class SearchIndexer
  MIN_POST_BLURB_INDEX_VERSION = 4

  POST_INDEX_VERSION = 5
  TOPIC_INDEX_VERSION = 4
  CATEGORY_INDEX_VERSION = 3
  USER_INDEX_VERSION = 3
  TAG_INDEX_VERSION = 3

  # version to apply when issuing a background reindex
  REINDEX_VERSION = 0
  TS_VECTOR_PARSE_REGEX = /('([^']*|'')*'\:)(([0-9]+[A-D]?,?)+)/

  def self.disable
    @disabled = true
  end

  def self.enable
    @disabled = false
  end

  def self.with_indexing
    prior = @disabled
    enable
    yield
  ensure
    @disabled = prior
  end

  def self.update_index(table:, id:, a_weight: nil, b_weight: nil, c_weight: nil, d_weight: nil)
    raw_data = { a: a_weight, b: b_weight, c: c_weight, d: d_weight }

    # The version used in excerpts
    search_data = raw_data.transform_values { |data| Search.prepare_data(data || "", :index) }

    # The version used to build the index
    indexed_data =
      search_data.transform_values do |data|
        data.gsub(/\S+/) { |word| word[0...SiteSetting.search_max_indexed_word_length] }
      end

    table_name = "#{table}_search_data"
    foreign_key = "#{table}_id"

    # for user login and name use "simple" lowercase stemmer
    stemmer = table == "user" ? "simple" : Search.ts_config

    ranked_index = <<~SQL
      setweight(to_tsvector('#{stemmer}', #{Search.wrap_unaccent("coalesce(:a,''))")}, 'A') ||
      setweight(to_tsvector('#{stemmer}', #{Search.wrap_unaccent("coalesce(:b,''))")}, 'B') ||
      setweight(to_tsvector('#{stemmer}', #{Search.wrap_unaccent("coalesce(:c,''))")}, 'C') ||
      setweight(to_tsvector('#{stemmer}', #{Search.wrap_unaccent("coalesce(:d,''))")}, 'D')
    SQL

    tsvector = DB.query_single("SELECT #{ranked_index}", indexed_data)[0]
    additional_lexemes = []

    # we also want to index parts of a domain name
    # that way stemmed single word searches will match
    additional_words = []

    tsvector
      .scan(/'(([a-zA-Z0-9]+\.)+[a-zA-Z0-9]+)'\:([\w+,]+)/)
      .reduce(additional_lexemes) do |array, (lexeme, _, positions)|
        count = 0

        if lexeme !~ /\A(\d+\.)?(\d+\.)*(\*|\d+)\z/
          loop do
            count += 1
            break if count >= 10 # Safeguard here to prevent infinite loop when a term has many dots
            term, _, remaining = lexeme.partition(".")
            break if remaining.blank?

            additional_words << [term, positions]

            array << "'#{remaining}':#{positions}"
            lexeme = remaining
          end
        end

        array
      end

    extra_domain_word_terms =
      if additional_words.length > 0
        DB
          .query_single(
            "SELECT to_tsvector(?, ?)",
            stemmer,
            additional_words.map { |term, _| term }.join(" "),
          )
          .first
          .scan(TS_VECTOR_PARSE_REGEX)
          .map do |term, _, indexes|
            new_indexes =
              indexes
                .split(",")
                .map do |index|
                  existing_positions = additional_words[index.to_i - 1]
                  if existing_positions
                    existing_positions[1]
                  else
                    index
                  end
                end
                .join(",")
            "#{term}#{new_indexes}"
          end
          .join(" ")
      end

    tsvector = "#{tsvector} #{additional_lexemes.join(" ")} #{extra_domain_word_terms}"

    if (max_dupes = SiteSetting.max_duplicate_search_index_terms) > 0
      reduced = []
      tsvector
        .scan(TS_VECTOR_PARSE_REGEX)
        .each do |term, _, indexes|
          family_counts = Hash.new(0)
          new_index_array = []

          indexes
            .split(",")
            .each do |index|
              family = nil
              family = index[-1] if index[-1].match?(/[A-D]/)
              # title dupes can completely dominate the index
              # so we limit them to 1
              if (family_counts[family] += 1) <= (family == "A" ? 1 : max_dupes)
                new_index_array << index
              end
            end
          reduced << "#{term.strip}#{new_index_array.join(",")}"
        end
      tsvector = reduced.join(" ")
    end

    indexed_data =
      if table.to_s == "post"
        clean_post_raw_data!(search_data[:d])
      else
        search_data.values.select { |d| d.length > 0 }.join(" ")
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
        env: {
          id: id,
        },
      )
    end
  end

  def self.update_topics_index(topic_id, title, cooked)
    # a bit inconsistent that we use title as A and body as B when in
    # the post index body is D
    update_index(
      table: "topic",
      id: topic_id,
      a_weight: title,
      b_weight: HtmlScrubber.scrub(cooked)[0...Topic::MAX_SIMILAR_BODY_LENGTH],
    )
  end

  def self.update_posts_index(
    post_id:,
    topic_title:,
    category_name:,
    topic_tags:,
    cooked:,
    private_message:
  )
    update_index(
      table: "post",
      id: post_id,
      a_weight: topic_title,
      b_weight: category_name,
      c_weight: topic_tags,
      # The tsvector resulted from parsing a string can be double the size of
      # the original string. Since there is no way to estimate the length of
      # the expected tsvector, we limit the input to ~50% of the maximum
      # length of a tsvector (1_048_576 bytes).
      d_weight: HtmlScrubber.scrub(cooked)[0..600_000],
    ) { |params| params["private_message"] = private_message }
  end

  def self.update_users_index(user_id, username, name, custom_fields)
    update_index(
      table: "user",
      id: user_id,
      a_weight: username,
      b_weight: name,
      c_weight: custom_fields,
    )
  end

  def self.update_categories_index(category_id, name)
    update_index(table: "category", id: category_id, a_weight: name)
  end

  def self.update_tags_index(tag_id, name)
    update_index(table: "tag", id: tag_id, a_weight: name.downcase)
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
        tag_names =
          (tags.map(&:name) + Tag.where(target_tag_id: tags.map(&:id)).pluck(:name)).join(" ")
      end
    end

    if Post === obj && obj.raw.present? &&
         (force || obj.saved_change_to_cooked? || obj.saved_change_to_topic_id?)
      if topic
        SearchIndexer.update_posts_index(
          post_id: obj.id,
          topic_title: topic.title,
          category_name: category_name,
          topic_tags: tag_names,
          cooked: obj.cooked,
          private_message: topic.private_message?,
        )

        SearchIndexer.update_topics_index(topic.id, topic.title, obj.cooked) if obj.is_first_post?
      end
    end

    if User === obj && (obj.saved_change_to_username? || obj.saved_change_to_name? || force)
      SearchIndexer.update_users_index(
        obj.id,
        obj.username_lower || "",
        obj.name ? obj.name.downcase : "",
        obj.user_custom_fields.searchable.map(&:value).join(" "),
      )
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
            private_message: obj.private_message?,
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

    def initialize
      @scrubbed = +""
    end

    def self.scrub(html)
      return +"" if html.blank?

      begin
        document = Nokogiri.HTML5("<div>#{html}</div>", nil, Encoding::UTF_8.to_s)
      rescue ArgumentError
        return +""
      end

      nodes = document.css("div.#{CookedPostProcessor::LIGHTBOX_WRAPPER_CSS_CLASS}")

      if nodes.present?
        nodes.each do |node|
          node.traverse do |child_node|
            next if child_node == node

            if %w[a img].exclude?(child_node.name)
              child_node.remove
            elsif child_node.name == "a"
              ATTRIBUTES.each { |attribute| child_node.remove_attribute(attribute) }
            end
          end
        end
      end

      document.css("img.emoji").each { |node| node.remove_attribute("alt") }

      document
        .css("a[href]")
        .each do |node|
          if node["href"] == node.text || MENTION_CLASSES.include?(node["class"])
            node.remove_attribute("href")
          end

          if node["class"] == "anchor" && node["href"].starts_with?("#")
            node.remove_attribute("href")
          end
        end

      html_scrubber = new
      Nokogiri::HTML::SAX::Parser.new(html_scrubber).parse(document.to_html)
      html_scrubber.scrubbed.squish
    end

    MENTION_CLASSES = %w[mention mention-group].freeze
    ATTRIBUTES = %w[alt title href data-video-title].freeze

    def start_element(_name, attributes = [])
      attributes = Hash[*attributes.flatten]

      ATTRIBUTES.each do |attribute_name|
        if attributes[attribute_name].present? &&
             !(attribute_name == "href" && UrlHelper.is_local(attributes[attribute_name]))
          characters(attributes[attribute_name])
        end
      end
    end

    def characters(str)
      scrubbed << " #{str} "
    end
  end
end
