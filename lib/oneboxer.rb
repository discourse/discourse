require 'uri'
require_dependency "onebox/discourse_onebox_sanitize_config"
require_dependency 'final_destination'

Dir["#{Rails.root}/lib/onebox/engine/*_onebox.rb"].sort.each { |f| require f }

module Oneboxer
  # keep reloaders happy
  unless defined? Oneboxer::Result
    Result = Struct.new(:doc, :changed) do
      def to_html
        doc.to_html
      end

      def changed?
        changed
      end
    end
  end

  def self.ignore_redirects
    @ignore_redirects ||= ['http://www.dropbox.com', 'http://store.steampowered.com', Discourse.base_url]
  end

  def self.force_get_hosts
    @force_get_hosts ||= ['http://us.battle.net']
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
    if c = Rails.cache.read(onebox_cache_key(url))
      c[:onebox]
    end
  rescue => e
    invalidate(url)
    Rails.logger.warn("invalid cached onebox for #{url} #{e}")
    ""
  end

  def self.cached_preview(url)
    if c = Rails.cache.read(onebox_cache_key(url))
      c[:preview]
    end
  rescue => e
    invalidate(url)
    Rails.logger.warn("invalid cached preview for #{url} #{e}")
    ""
  end

  def self.invalidate(url)
    Rails.cache.delete(onebox_cache_key(url))
  end

  # Parse URLs out of HTML, returning the document when finished.
  def self.each_onebox_link(string_or_doc)
    doc = string_or_doc
    doc = Nokogiri::HTML::fragment(doc) if doc.is_a?(String)

    onebox_links = doc.search("a.onebox")
    if onebox_links.present?
      onebox_links.each do |link|
        yield(link['href'], link) if link['href'].present?
      end
    end

    doc
  end

  HTML5_BLOCK_ELEMENTS ||= %w{address article aside blockquote canvas center dd div dl dt fieldset figcaption figure footer form h1 h2 h3 h4 h5 h6 header hgroup hr li main nav noscript ol output p pre section table tfoot ul video}

  def self.apply(string_or_doc, args = nil)
    doc = string_or_doc
    doc = Nokogiri::HTML::fragment(doc) if doc.is_a?(String)
    changed = false

    each_onebox_link(doc) do |url, element|
      onebox, _ = yield(url, element)
      if onebox
        parsed_onebox = Nokogiri::HTML::fragment(onebox)
        next unless parsed_onebox.children.count > 0

        if element&.parent&.node_name&.downcase == "p" &&
           element.parent.children.count == 1 &&
           HTML5_BLOCK_ELEMENTS.include?(parsed_onebox.children[0].node_name.downcase)
          element = element.parent
        end

        changed = true
        element.swap parsed_onebox.to_html
      end
    end

    # strip empty <p> elements
    doc.css("p").each { |p| p.remove if p.children.empty? }

    Result.new(doc, changed)
  end

  def self.is_previewing?(user_id)
    $redis.get(preview_key(user_id)) == "1"
  end

  def self.preview_onebox!(user_id)
    $redis.setex(preview_key(user_id), 1.minute, "1")
  end

  def self.onebox_previewed!(user_id)
    $redis.del(preview_key(user_id))
  end

  def self.engine(url)
    Onebox::Matcher.new(url).oneboxed
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

  def self.onebox_raw(url, opts = {})
    url = URI(url).to_s
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
      when "uploads" then local_upload_html(url)
      when "topics"  then local_topic_html(url, route, opts)
      when "users"   then local_user_html(url, route)
      end

    html = html.presence || "<a href='#{url}'>#{url}</a>"
    { onebox: html, preview: html }
  end

  def self.local_upload_html(url)
    case File.extname(URI(url).path || "")
    when /^\.(mov|mp4|webm|ogv)$/i
      "<video width='100%' height='100%' controls><source src='#{url}'><a href='#{url}'>#{url}</a></video>"
    when /^\.(mp3|ogg|wav|m4a)$/i
      "<audio controls><source src='#{url}'><a href='#{url}'>#{url}</a></audio>"
    end
  end

  def self.local_topic_html(url, route, opts)
    return unless current_user = User.find_by(id: opts[:user_id])

    if current_category = Category.find_by(id: opts[:category_id])
      return unless Guardian.new(current_user).can_see_category?(current_category)
    end

    if current_topic = Topic.find_by(id: opts[:topic_id])
      return unless Guardian.new(current_user).can_see_topic?(current_topic)
    end

    topic = Topic.find_by(id: route[:topic_id])

    return unless topic
    return if topic.private_message?

    if current_category&.id != topic.category_id
      return unless Guardian.new.can_see_topic?(topic)
    end

    post_number = route[:post_number].to_i

    post = post_number > 1 ?
      topic.posts.where(post_number: post_number).first :
      topic.ordered_posts.first

    return if !post || post.hidden || post.post_type != Post.types[:regular]

    if post_number > 1 && current_topic&.id == topic.id
      excerpt = post.excerpt(SiteSetting.post_onebox_maxlength)
      excerpt.gsub!(/[\r\n]+/, " ")
      excerpt.gsub!("[/quote]", "[quote]") # don't break my quote

      quote = "[quote=\"#{post.user.username}, topic:#{topic.id}, post:#{post.post_number}\"]\n#{excerpt}\n[/quote]"

      PrettyText.cook(quote)
    else
      args = {
        topic_id: topic.id,
        post_number: post.post_number,
        avatar: PrettyText.avatar_img(post.user.avatar_template, "tiny"),
        original_url: url,
        title: PrettyText.unescape_emoji(CGI::escapeHTML(topic.title)),
        category_html: CategoryBadge.html_for(topic.category),
        quote: PrettyText.unescape_emoji(post.excerpt(SiteSetting.post_onebox_maxlength)),
      }

      template = File.read("#{Rails.root}/lib/onebox/templates/discourse_topic_onebox.hbs")
      Mustache.render(template, args)
    end
  end

  def self.local_user_html(url, route)
    username = route[:username] || ""

    if user = User.find_by(username_lower: username.downcase)
      args = {
        user_id: user.id,
        username: user.username,
        avatar: PrettyText.avatar_img(user.avatar_template, "extra_large"),
        name: user.name,
        bio: user.user_profile.bio_excerpt(230),
        location: user.user_profile.location,
        joined: I18n.t('joined'),
        created_at: user.created_at.strftime(I18n.t('datetime_formats.formats.date_only')),
        website: user.user_profile.website,
        website_name: UserSerializer.new(user).website_name,
        original_url: url
      }

      template = File.read("#{Rails.root}/lib/onebox/templates/discourse_user_onebox.hbs")
      Mustache.render(template, args)
    else
      nil
    end
  end

  def self.external_onebox(url)
    Rails.cache.fetch(onebox_cache_key(url), expires_in: 1.day) do
      fd = FinalDestination.new(url, ignore_redirects: ignore_redirects, force_get_hosts: force_get_hosts)
      uri = fd.resolve
      return blank_onebox if uri.blank? || SiteSetting.onebox_domains_blacklist.include?(uri.hostname)

      options = {
        cache: {},
        max_width: 695,
        sanitize_config: Sanitize::Config::DISCOURSE_ONEBOX
      }

      options[:cookie] = fd.cookie if fd.cookie

      if Rails.env.development? && SiteSetting.port.to_i > 0
        Onebox.options = { allowed_ports: [80, 443, SiteSetting.port.to_i] }
      end

      r = Onebox.preview(uri.to_s, options)

      { onebox: r.to_s, preview: r&.placeholder_html.to_s }
    end
  end

end
