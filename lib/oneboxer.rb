# frozen_string_literal: true

require "uri"

Dir["#{Rails.root}/lib/onebox/engine/*_onebox.rb"].sort.each { |f| require f }

module Oneboxer
  ONEBOX_CSS_CLASS = "onebox"
  AUDIO_REGEX = /\A\.(mp3|og[ga]|opus|wav|m4[abpr]|aac|flac)\z/i
  VIDEO_REGEX = /\A\.(mov|mp4|webm|m4v|3gp|ogv|avi|mpeg|ogv)\z/i

  # keep reloaders happy
  unless defined?(Oneboxer::Result)
    Result =
      Struct.new(:doc, :changed) do
        def to_html
          doc.to_html
        end

        def changed?
          changed
        end
      end
  end

  def self.ignore_redirects
    @ignore_redirects ||= [
      "http://www.dropbox.com",
      "http://store.steampowered.com",
      "http://vimeo.com",
      "https://www.youtube.com",
      "https://twitter.com",
      Discourse.base_url,
    ]
  end

  def self.amazon_domains
    amazon_suffixes = %w[
      com
      com.br
      ca
      cn
      fr
      de
      in
      it
      co.jp
      com.mx
      nl
      pl
      sa
      sg
      es
      se
      com.tr
      ae
      co.uk
    ]
    amazon_suffixes.collect { |suffix| "https://www.amazon.#{suffix}" }
  end

  def self.force_get_hosts
    hosts = []
    hosts += SiteSetting.force_get_hosts.split("|").collect { |domain| "https://#{domain}" }
    hosts +=
      SiteSetting
        .cache_onebox_response_body_domains
        .split("|")
        .collect { |domain| "https://www.#{domain}" }
    hosts += amazon_domains

    hosts.uniq
  end

  def self.force_custom_user_agent_hosts
    SiteSetting.force_custom_user_agent_hosts.split("|")
  end

  def self.allowed_post_types
    @allowed_post_types ||= [Post.types[:regular], Post.types[:moderator_action]]
  end

  def self.local_handlers
    @local_handlers ||= {}
  end

  def self.register_local_handler(controller, &handler)
    local_handlers[controller] = handler
  end

  def self.preview(url, options = nil)
    options ||= {}
    invalidate(url) if options[:invalidate_oneboxes]
    onebox_raw(url, options)[:preview]
  end

  def self.onebox(url, options = nil)
    options ||= {}
    invalidate(url) if options[:invalidate_oneboxes]
    onebox_raw(url, options)[:onebox]
  end

  def self.cached_onebox(url)
    if c = Discourse.cache.read(onebox_cache_key(url))
      c[:onebox]
    end
  rescue => e
    invalidate(url)
    Rails.logger.warn("invalid cached onebox for #{url} #{e}")
    ""
  end

  def self.cached_preview(url)
    if c = Discourse.cache.read(onebox_cache_key(url))
      c[:preview]
    end
  rescue => e
    invalidate(url)
    Rails.logger.warn("invalid cached preview for #{url} #{e}")
    ""
  end

  def self.invalidate(url)
    Discourse.cache.delete(onebox_cache_key(url))
    Discourse.cache.delete(onebox_failed_cache_key(url))
  end

  def self.cache_response_body?(uri)
    uri = URI.parse(uri) if uri.is_a?(String)

    if SiteSetting.cache_onebox_response_body?
      SiteSetting
        .cache_onebox_response_body_domains
        .split("|")
        .any? { |domain| uri.hostname.ends_with?(domain) }
    end
  end

  def self.cache_response_body(uri, response)
    key = redis_cached_response_body_key(uri)
    Discourse.redis.without_namespace.setex(key, 1.minutes.to_i, response)
  end

  def self.cached_response_body_exists?(uri)
    key = redis_cached_response_body_key(uri)
    Discourse.redis.without_namespace.exists(key).to_i > 0
  end

  def self.fetch_cached_response_body(uri)
    key = redis_cached_response_body_key(uri)
    Discourse.redis.without_namespace.get(key)
  end

  def self.redis_cached_response_body_key(uri)
    "CACHED_RESPONSE_#{onebox_locale}_#{uri}"
  end

  # Parse URLs out of HTML, returning the document when finished.
  def self.each_onebox_link(doc, extra_paths: [])
    onebox_links = doc.css("a.#{ONEBOX_CSS_CLASS}", *extra_paths)
    if onebox_links.present?
      onebox_links.each { |link| yield(link["href"], link) if link["href"].present? }
    end

    doc
  end

  HTML5_BLOCK_ELEMENTS = %w[
    address
    article
    aside
    blockquote
    canvas
    center
    dd
    div
    dl
    dt
    fieldset
    figcaption
    figure
    footer
    form
    h1
    h2
    h3
    h4
    h5
    h6
    header
    hgroup
    hr
    li
    main
    nav
    noscript
    ol
    output
    p
    pre
    section
    table
    tfoot
    ul
    video
  ]

  def self.apply(string_or_doc, extra_paths: nil)
    doc = string_or_doc
    doc = Loofah.html5_fragment(doc) if doc.is_a?(String)
    changed = false

    each_onebox_link(doc, extra_paths: extra_paths) do |url, element|
      onebox, _ = yield(url, element)
      next if onebox.blank?

      parsed_onebox = Loofah.html5_fragment(onebox)
      next if parsed_onebox.children.blank?

      changed = true

      parent = element.parent
      if parent&.node_name&.downcase == "p" &&
           parsed_onebox.children.any? { |child|
             HTML5_BLOCK_ELEMENTS.include?(child.node_name.downcase)
           }
        siblings = parent.children
        element_idx = siblings.find_index(element)
        before_idx = first_significant_element_index(siblings, element_idx - 1, -1)
        after_idx = first_significant_element_index(siblings, element_idx + 1, +1)

        if before_idx < 0 && after_idx >= siblings.size
          parent.replace parsed_onebox
        elsif before_idx < 0
          parent.children = siblings[after_idx..siblings.size]
          parent.add_previous_sibling(parsed_onebox)
        elsif after_idx >= siblings.size
          parent.children = siblings[0..before_idx]
          parent.add_next_sibling(parsed_onebox)
        else
          parent_rest = parent.dup

          parent.children = siblings[0..before_idx]
          parent_rest.children = siblings[after_idx..siblings.size]

          parent.add_next_sibling(parent_rest)
          parent.add_next_sibling(parsed_onebox)
        end
      else
        element.replace parsed_onebox
      end
    end

    Result.new(doc, changed)
  end

  def self.first_significant_element_index(elements, index, step)
    while index >= 0 && index < elements.size &&
            (
              elements[index].node_name.downcase == "br" ||
                (
                  elements[index].node_name.downcase == "text" &&
                    elements[index].to_html.strip.blank?
                )
            )
      index = index + step
    end

    index
  end

  def self.is_previewing?(user_id)
    Discourse.redis.get(preview_key(user_id)) == "1"
  end

  def self.preview_onebox!(user_id)
    Discourse.redis.setex(preview_key(user_id), 1.minute, "1")
  end

  def self.onebox_previewed!(user_id)
    Discourse.redis.del(preview_key(user_id))
  end

  def self.engine(url)
    Onebox::Matcher.new(
      url,
      { allowed_iframe_regexes: Onebox::Engine.origins_to_regexes(allowed_iframe_origins) },
    ).oneboxed
  end

  def self.recently_failed?(url)
    Discourse.cache.read(onebox_failed_cache_key(url)).present?
  end

  def self.cache_failed!(url)
    Discourse.cache.write(onebox_failed_cache_key(url), true, expires_in: 1.hour)
  end

  private

  def self.preview_key(user_id)
    "onebox:preview:#{user_id}"
  end

  def self.blank_onebox
    { preview: "", onebox: "" }
  end

  def self.onebox_cache_key(url)
    "onebox__#{url}"
  end

  def self.onebox_failed_cache_key(url)
    "onebox_failed__#{url}"
  end

  def self.onebox_raw(url, opts = {})
    url = UrlHelper.normalized_encode(url).to_s
    local_onebox(url, opts) || external_onebox(url)
  rescue => e
    # no point warning here, just cause we have an issue oneboxing a url
    # we can later hunt for failed oneboxes by searching logs if needed
    Rails.logger.info("Failed to onebox #{url} #{e} #{e.backtrace}")
    # return a blank hash, so rest of the code works
    blank_onebox
  end

  def self.local_onebox(url, opts = {})
    return unless route = Discourse.route_for(url)

    html =
      case route[:controller]
      when "uploads"
        local_upload_html(url)
      when "topics"
        local_topic_html(url, route, opts)
      when "users"
        local_user_html(url, route)
      when "list"
        local_category_html(url, route)
      else
        if handler = local_handlers[route[:controller]]
          handler.call(url, route)
        end
      end

    normalized_url = ::Onebox::Helpers.normalize_url_for_output(URI(url).to_s)
    html = html.presence || "<a href='#{normalized_url}'>#{normalized_url}</a>"
    { onebox: html, preview: html }
  end

  def self.local_upload_html(url)
    additional_controls =
      if SiteSetting.disable_onebox_media_download_controls
        "controlslist='nodownload'"
      else
        ""
      end

    normalized_url = ::Onebox::Helpers.normalize_url_for_output(url)
    case File.extname(URI(url).path || "")
    when VIDEO_REGEX
      <<~HTML
        <div class="onebox video-onebox">
          <video #{additional_controls} width="100%" height="100%" controls="">
            <source src='#{normalized_url}'>
            <a href='#{normalized_url}'>
              #{normalized_url}
            </a>
          </video>
        </div>
      HTML
    when AUDIO_REGEX
      <<~HTML
        <audio #{additional_controls} controls>
          <source src='#{normalized_url}'>
          <a href='#{normalized_url}'>
            #{normalized_url}
          </a>
        </audio>
      HTML
    end
  end

  def self.local_topic(url, route, opts)
    if current_user = User.find_by(id: opts[:user_id])
      if current_category = Category.find_by(id: opts[:category_id])
        return unless Guardian.new(current_user).can_see_category?(current_category)
      end

      if current_topic = Topic.find_by(id: opts[:topic_id])
        return unless Guardian.new(current_user).can_see_topic?(current_topic)
      end
    end

    return unless topic = Topic.find_by(id: route[:id] || route[:topic_id])
    return if topic.private_message?

    if current_category.blank? || current_category.id != topic.category_id
      return unless Guardian.new.can_see_topic?(topic)
    end

    topic
  end

  def self.local_topic_html(url, route, opts)
    return unless topic = local_topic(url, route, opts)

    post_number = route[:post_number].to_i

    post =
      (
        if post_number > 1
          topic.posts.where(post_number: post_number).first
        else
          topic.ordered_posts.first
        end
      )

    return if !post || post.hidden || !allowed_post_types.include?(post.post_type)

    if post_number > 1 && opts[:topic_id] == topic.id
      excerpt = post.excerpt(SiteSetting.post_onebox_maxlength, keep_svg: true)
      excerpt.gsub!(/[\r\n]+/, " ")
      excerpt.gsub!("[/quote]", "[quote]") # don't break my quote

      quote =
        "[quote=\"#{post.user.username}, topic:#{topic.id}, post:#{post.post_number}\"]\n#{excerpt}\n[/quote]"

      PrettyText.cook(quote)
    else
      args = {
        topic_id: topic.id,
        post_number: post.post_number,
        avatar: PrettyText.avatar_img(post.user.avatar_template_url, "tiny"),
        original_url: url,
        title: PrettyText.unescape_emoji(CGI.escapeHTML(topic.title)),
        category_html: CategoryBadge.html_for(topic.category),
        quote:
          PrettyText.unescape_emoji(
            post.excerpt(SiteSetting.post_onebox_maxlength, keep_svg: true),
          ),
      }

      template = template("discourse_topic_onebox")
      Mustache.render(template, args)
    end
  end

  def self.local_user_html(url, route)
    username = route[:username] || ""

    if user = User.find_by(username_lower: username.downcase)
      name = user.name if SiteSetting.enable_names

      args = {
        user_id: user.id,
        username: user.username,
        avatar: PrettyText.avatar_img(user.avatar_template, "huge"),
        name: name,
        bio: user.user_profile.bio_excerpt(230),
        location: Onebox::Helpers.sanitize(user.user_profile.location),
        joined:
          I18n.t(
            "onebox.discourse.user_joined_community",
            date: user.created_at.strftime(I18n.t("datetime_formats.formats.date_only")),
          ),
        website: user.user_profile.website,
        website_name: UserSerializer.new(user).website_name,
        original_url: url,
      }

      Mustache.render(template("discourse_user_onebox"), args)
    else
      nil
    end
  end

  def self.local_category_html(url, route)
    return unless route[:category_slug_path_with_id]
    category = Category.find_by_slug_path_with_id(route[:category_slug_path_with_id])

    if Guardian.new.can_see_category?(category)
      args = {
        url: category.url,
        name: category.name,
        color: category.color,
        logo_url: category.uploaded_logo&.url,
        description: Onebox::Helpers.sanitize(category.description),
        has_subcategories: category.subcategories.present?,
        subcategories:
          category.subcategories.collect { |sc| { name: sc.name, color: sc.color, url: sc.url } },
      }

      Mustache.render(template("discourse_category_onebox"), args)
    end
  end

  def self.preserve_fragment_url_hosts
    @preserve_fragment_url_hosts ||= ["http://github.com"]
  end

  def self.allowed_iframe_origins
    allowed = SiteSetting.allowed_onebox_iframes.split("|")
    allowed = Onebox::Engine.all_iframe_origins if allowed.include?("*")
    allowed += SiteSetting.allowed_iframes.split("|")
  end

  def self.external_onebox(url, available_strategies = nil)
    Discourse
      .cache
      .fetch(onebox_cache_key(url), expires_in: 1.day) do
        uri = URI(url)
        available_strategies ||= Oneboxer.ordered_strategies(uri.hostname)
        strategy = available_strategies.shift

        max_redirects = 0 if SiteSetting.block_onebox_on_redirect
        fd =
          FinalDestination.new(
            url,
            get_final_destination_options(url, strategy).merge(
              stop_at_blocked_pages: true,
              max_redirects: max_redirects,
              initial_https_redirect_ignore_limit: SiteSetting.block_onebox_on_redirect,
            ),
          )
        uri = fd.resolve

        return blank_onebox if fd.status == :blocked_page

        if fd.status != :resolved
          args = { link: url }
          if fd.status == :invalid_address
            args[:error_message] = I18n.t("errors.onebox.invalid_address", hostname: fd.hostname)
          elsif (fd.status_code || uri.nil?) && available_strategies.present?
            # Try a different oneboxing strategy, if we have any options left:
            return external_onebox(url, available_strategies)
          elsif fd.status_code
            args[:error_message] = I18n.t(
              "errors.onebox.error_response",
              status_code: fd.status_code,
            )
          end

          error_box = blank_onebox
          error_box[:preview] = preview_error_onebox(args)
          return error_box
        end

        return blank_onebox if uri.blank?

        onebox_options = {
          max_width: 695,
          sanitize_config: Onebox::SanitizeConfig::DISCOURSE_ONEBOX,
          allowed_iframe_origins: allowed_iframe_origins,
          hostname: GlobalSetting.hostname,
          facebook_app_access_token: SiteSetting.facebook_app_access_token,
          disable_media_download_controls: SiteSetting.disable_onebox_media_download_controls,
          body_cacher: self,
          content_type: fd.content_type,
        }

        onebox_options[:cookie] = fd.cookie if fd.cookie

        user_agent_override = SiteSetting.cache_onebox_user_agent if Oneboxer.cache_response_body?(
          url,
        ) && SiteSetting.cache_onebox_user_agent.present?
        onebox_options[:user_agent] = user_agent_override if user_agent_override

        preview_result = Onebox.preview(uri.to_s, onebox_options)
        result = {
          onebox: WordWatcher.censor(preview_result.to_s),
          preview: WordWatcher.censor(preview_result.placeholder_html.to_s),
        }

        # NOTE: Call preview_result.errors after calling placeholder_html
        if preview_result.errors.any?
          error_keys = preview_result.errors.keys
          skip_if_only_error = [:image]
          unless error_keys.length == 1 && skip_if_only_error.include?(error_keys.first)
            missing_attributes = error_keys.map(&:to_s).sort.join(I18n.t("word_connector.comma"))
            error_message =
              I18n.t(
                "errors.onebox.missing_data",
                missing_attributes: missing_attributes,
                count: error_keys.size,
              )
            args = preview_result.verified_data.merge(error_message: error_message)

            if result[:preview].blank?
              result[:preview] = preview_error_onebox(args)
            else
              doc = Nokogiri::HTML5.fragment(result[:preview])
              aside = doc.at("aside")

              if aside
                # Add an error message to the preview that was returned
                error_fragment = preview_error_onebox_fragment(args)
                aside.add_child(error_fragment)
                result[:preview] = doc.to_html
              end
            end
          end
        end

        Oneboxer.cache_preferred_strategy(uri.hostname, strategy)

        result
      end
  end

  def self.preview_error_onebox(args, is_fragment = false)
    args[:title] ||= args[:link] if args[:link]
    args[:error_message] = PrettyText.unescape_emoji(args[:error_message]) if args[:error_message]

    template_name = is_fragment ? "preview_error_fragment_onebox" : "preview_error_onebox"
    Mustache.render(template(template_name), args)
  end

  def self.preview_error_onebox_fragment(args)
    preview_error_onebox(args, true)
  end

  def self.template(template_name)
    @template_cache ||= {}
    @template_cache[template_name] ||= begin
      full_path = "#{Rails.root}/lib/onebox/templates/#{template_name}.mustache"
      File.read(full_path)
    end
  end

  def self.ordered_strategies(hostname)
    all = strategies.keys
    preferred = Oneboxer.preferred_strategy(hostname)

    all.insert(0, all.delete(preferred)) if all.include?(preferred)

    all
  end

  def self.strategies
    {
      default: {
      }, # don't override anything by default
      force_get_and_ua: {
        force_get_host: true,
        force_custom_user_agent_host: true,
      },
    }
  end

  def self.cache_preferred_strategy(hostname, strategy)
    return if strategy == :default

    key = redis_oneboxer_strategy_key(hostname)
    Discourse.redis.without_namespace.setex(key, 2.weeks.to_i, strategy.to_s)
  end

  def self.clear_preferred_strategy!(hostname)
    key = redis_oneboxer_strategy_key(hostname)
    Discourse.redis.without_namespace.del(key)
  end

  def self.preferred_strategy(hostname)
    key = redis_oneboxer_strategy_key(hostname)
    Discourse.redis.without_namespace.get(key)&.to_sym
  end

  def self.redis_oneboxer_strategy_key(hostname)
    "ONEBOXER_STRATEGY_#{hostname}"
  end

  def self.get_final_destination_options(url, strategy = nil)
    fd_options = {
      ignore_redirects: ignore_redirects,
      force_get_hosts: force_get_hosts,
      force_custom_user_agent_hosts: force_custom_user_agent_hosts,
      preserve_fragment_url_hosts: preserve_fragment_url_hosts,
      timeout: 5,
      extra_headers: {
        "Accept-Language" => accept_language,
      },
    }

    uri = URI(url)

    # For private GitHub repos, we get a 404 when trying to use
    # FinalDestination to request the final URL because no auth headers
    # are sent. In this case we can ignore redirects and go straight to
    # using Onebox.preview
    if SiteSetting.github_onebox_access_tokens.present? && uri.hostname == "github.com"
      fd_options[:ignore_redirects] << "https://github.com"
    end

    strategy = Oneboxer.ordered_strategies(uri.hostname).shift if strategy.blank?

    if strategy && Oneboxer.strategies[strategy][:force_get_host]
      fd_options[:force_get_hosts] = ["https://#{uri.hostname}"]
    end
    if strategy && Oneboxer.strategies[strategy][:force_custom_user_agent_host]
      fd_options[:force_custom_user_agent_hosts] = ["https://#{uri.hostname}"]
    end

    user_agent_override = SiteSetting.cache_onebox_user_agent if Oneboxer.cache_response_body?(
      url,
    ) && SiteSetting.cache_onebox_user_agent.present?
    fd_options[:default_user_agent] = user_agent_override if user_agent_override

    fd_options
  end

  def self.onebox_locale
    SiteSetting.onebox_locale.presence || SiteSetting.default_locale
  end

  def self.accept_language
    if onebox_locale == "en"
      "en;q=0.9, *;q=0.5"
    else
      "#{onebox_locale.gsub(/_/, "-")};q=0.9, en;q=0.8, *;q=0.5"
    end
  end
end
