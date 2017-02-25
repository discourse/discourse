require_dependency "#{Rails.root}/lib/onebox/discourse_onebox_sanitize_config"
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

  def self.preview(url, options=nil)
    options ||= {}
    invalidate(url) if options[:invalidate_oneboxes]
    onebox_raw(url)[:preview]
  end

  def self.onebox(url, options=nil)
    options ||= {}
    invalidate(url) if options[:invalidate_oneboxes]
    onebox_raw(url)[:onebox]
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

  def self.append_source_topic_id(url, topic_id)
    # hack urls to create proper expansions
    if url =~ Regexp.new("^#{Discourse.base_url.gsub(".","\\.")}.*$", true)
      uri = URI.parse(url) rescue nil
      if uri && uri.path
        route = Rails.application.routes.recognize_path(uri.path) rescue nil
        if route && route[:controller] == 'topics'
          url += (url =~ /\?/ ? "&" : "?") + "source_topic_id=#{topic_id}"
        end
      end
    end
    url
  end

  def self.apply(string_or_doc, args=nil)
    doc = string_or_doc
    doc = Nokogiri::HTML::fragment(doc) if doc.is_a?(String)
    changed = false

    each_onebox_link(doc) do |url, element|
      if args && args[:topic_id]
        url = append_source_topic_id(url, args[:topic_id])
      end
      onebox, _preview = yield(url,element)
      if onebox
        parsed_onebox = Nokogiri::HTML::fragment(onebox)
        next unless parsed_onebox.children.count > 0

        # special logic to strip empty p elements
        if  element.parent &&
            element.parent.node_name &&
            element.parent.node_name.downcase == "p" &&
            element.parent.children.count == 1
          element = element.parent
        end
        changed = true
        element.swap parsed_onebox.to_html
      end
    end

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

    def self.onebox_raw(url)
      Rails.cache.fetch(onebox_cache_key(url), expires_in: 1.day) do
        uri = URI(url) rescue nil
        return blank_onebox if uri.blank? || SiteSetting.onebox_domains_blacklist.include?(uri.hostname)
        options = { cache: {}, max_width: 695, sanitize_config: Sanitize::Config::DISCOURSE_ONEBOX }
        r = Onebox.preview(url, options)
        { onebox: r.to_s, preview: r.try(:placeholder_html).to_s }
      end
    rescue => e
      # no point warning here, just cause we have an issue oneboxing a url
      # we can later hunt for failed oneboxes by searching logs if needed
      Rails.logger.info("Failed to onebox #{url} #{e} #{e.backtrace}")
      # return a blank hash, so rest of the code works
      blank_onebox
    end

end
