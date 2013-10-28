require 'v8'
require 'nokogiri'
require_dependency 'excerpt_parser'
require_dependency 'post'

module PrettyText

  class Helpers

    def t(key, opts)
      str = I18n.t("js." + key)
      if opts
        # TODO: server localisation has no parity with client
        # should be fixed
        opts.each do |k,v|
          str.gsub!("{{#{k}}}", v)
        end
      end
      str
    end

    # function here are available to v8
    def avatar_template(username)
      return "" unless username

      user = User.where(username_lower: username.downcase).first
      if user.present?
        user.avatar_template
      end
    end

    def is_username_valid(username)
      return false unless username
      username = username.downcase
      return User.exec_sql('select 1 from users where username_lower = ?', username).values.length == 1
    end
  end

  @mutex = Mutex.new
  @ctx_init = Mutex.new

  def self.mention_matcher
    Regexp.new("(\@[a-zA-Z0-9_]{#{User.username_length.begin},#{User.username_length.end}})")
  end

  def self.app_root
    Rails.root
  end

  def self.create_new_context
    ctx = V8::Context.new

    ctx["helpers"] = Helpers.new

    ctx_load(ctx,
             "vendor/assets/javascripts/md5.js",
              "vendor/assets/javascripts/lodash.js",
              "vendor/assets/javascripts/Markdown.Converter.js",
              "lib/headless-ember.js",
              "vendor/assets/javascripts/rsvp.js",
              Rails.configuration.ember.handlebars_location)

    ctx.eval("var Discourse = {}; Discourse.SiteSettings = #{SiteSetting.client_settings_json};")
    ctx.eval("var window = {}; window.devicePixelRatio = 2;") # hack to make code think stuff is retina
    ctx.eval("var I18n = {}; I18n.t = function(a,b){ return helpers.t(a,b); }");

    decorate_context(ctx)

    ctx_load(ctx,
              "vendor/assets/javascripts/better_markdown.js",
              "app/assets/javascripts/defer/html-sanitizer-bundle.js",
              "app/assets/javascripts/discourse/dialects/dialect.js",
              "app/assets/javascripts/discourse/lib/utilities.js",
              "app/assets/javascripts/discourse/lib/markdown.js")

    Dir["#{Rails.root}/app/assets/javascripts/discourse/dialects/**.js"].each do |dialect|
      unless dialect =~ /\/dialect\.js$/
        ctx.load(dialect)
      end
    end

    # Load server side javascripts
    if DiscoursePluginRegistry.server_side_javascripts.present?
      DiscoursePluginRegistry.server_side_javascripts.each do |ssjs|
        ctx.load(ssjs)
      end
    end

    ctx['quoteTemplate'] = File.open(app_root + 'app/assets/javascripts/discourse/templates/quote.js.shbrs') {|f| f.read}
    ctx['quoteEmailTemplate'] = File.open(app_root + 'lib/assets/quote_email.js.shbrs') {|f| f.read}
    ctx.eval("HANDLEBARS_TEMPLATES = {
      'quote': Handlebars.compile(quoteTemplate),
      'quote_email': Handlebars.compile(quoteEmailTemplate),
     };")

    ctx
  end

  def self.v8

    return @ctx if @ctx

    # ensure we only init one of these
    @ctx_init.synchronize do
      return @ctx if @ctx
      @ctx = create_new_context
    end
    @ctx
  end

  def self.decorate_context(context)
    context.eval("Discourse.SiteSettings = #{SiteSetting.client_settings_json};")
    context.eval("Discourse.CDN = '#{Rails.configuration.action_controller.asset_host}';")
    context.eval("Discourse.BaseUrl = 'http://#{RailsMultisite::ConnectionManagement.current_hostname}';")
    context.eval("Discourse.getURL = function(url) {return '#{Discourse::base_uri}' + url};")
  end

  def self.markdown(text, opts=nil)
    # we use the exact same markdown converter as the client
    # TODO: use the same extensions on both client and server (in particular the template for mentions)

    baked = nil

    @mutex.synchronize do
      context = v8
      # we need to do this to work in a multi site environment, many sites, many settings
      decorate_context(context)

      context_opts = opts || {}
      context_opts[:sanitize] ||= true
      context['opts'] = context_opts

      context['raw'] = text

      if Post.white_listed_image_classes.present?
        Post.white_listed_image_classes.each do |klass|
          context.eval("Discourse.Markdown.whiteListClass('#{klass}')")
        end
      end

      context.eval('opts["mentionLookup"] = function(u){return helpers.is_username_valid(u);}')
      context.eval('opts["lookupAvatar"] = function(p){return Discourse.Utilities.avatarImg({size: "tiny", avatarTemplate: helpers.avatar_template(p)});}')
      baked = context.eval('Discourse.Markdown.markdownConverter(opts).makeHtml(raw)')
    end

    # we need some minimal server side stuff, apply CDN and TODO filter disallowed markup
    baked = apply_cdn(baked, Rails.configuration.action_controller.asset_host)
    baked
  end

  # leaving this here, cause it invokes v8, don't want to implement twice
  def self.avatar_img(avatar_template, size)
    r = nil
    @mutex.synchronize do
      v8['avatarTemplate'] = avatar_template
      v8['size'] = size
      decorate_context(v8)
      r = v8.eval("Discourse.Utilities.avatarImg({ avatarTemplate: avatarTemplate, size: size });")
    end
    r
  end

  def self.apply_cdn(html, url)
    return html unless url

    image = /\.(png|jpg|jpeg|gif|bmp|tif|tiff)$/i
    relative = /^\/[^\/]/

    doc = Nokogiri::HTML.fragment(html)

    doc.css("a").each do |l|
      href = l["href"].to_s
      l["href"] = url + href if href =~ relative && href =~ image
    end

    doc.css("img").each do |l|
      src = l["src"].to_s
      l["src"] = url + src if src =~ relative
    end

    doc.to_s
  end

  def self.cook(text, opts={})
    cloned = opts.dup
    # we have a minor inconsistency
    cloned[:topicId] = opts[:topic_id]
    sanitized = markdown(text.dup, cloned)
    if SiteSetting.add_rel_nofollow_to_user_content
      sanitized = add_rel_nofollow_to_user_content(sanitized)
    end
    sanitized
  end

  def self.add_rel_nofollow_to_user_content(html)
    whitelist = []

    l = SiteSetting.exclude_rel_nofollow_domains
    if l.present?
      whitelist = l.split(",")
    end

    site_uri = nil
    doc = Nokogiri::HTML.fragment(html)
    doc.css("a").each do |l|
      href = l["href"].to_s
      begin
        uri = URI(href)
        site_uri ||= URI(Discourse.base_url)

        if  !uri.host.present? ||
            uri.host.ends_with?(site_uri.host) ||
            whitelist.any?{|u| uri.host.ends_with?(u)}
          # we are good no need for nofollow
        else
          l["rel"] = "nofollow"
        end
      rescue URI::InvalidURIError
        # add a nofollow anyway
        l["rel"] = "nofollow"
      end
    end
    doc.to_html
  end

  def self.extract_links(html)
    links = []
    doc = Nokogiri::HTML.fragment(html)
    # remove href inside quotes
    doc.css("aside.quote a").each { |l| l["href"] = "" }
    # extract all links from the post
    doc.css("a").each { |l| links << l["href"] unless l["href"].blank? }
    # extract links to quotes
    doc.css("aside.quote").each do |a|
      topic_id = a['data-topic']

      url = "/t/topic/#{topic_id}"
      if post_number = a['data-post']
        url << "/#{post_number}"
      end

      links << url
    end

    links
  end


  def self.excerpt(html, max_length, options={})
    ExcerptParser.get_excerpt(html, max_length, options)
  end

  def self.strip_links(string)
    return string if string.blank?

    # If the user is not basic, strip links from their bio
    fragment = Nokogiri::HTML.fragment(string)
    fragment.css('a').each {|a| a.replace(a.text) }
    fragment.to_html
  end

  protected

  def self.ctx_load(ctx, *files)
    files.each do |file|
      ctx.load(app_root + file)
    end
  end

end
