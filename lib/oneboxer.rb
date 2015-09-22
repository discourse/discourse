
Dir["#{Rails.root}/lib/onebox/engine/*_onebox.rb"].each {|f|
  require_dependency(f.split('/')[-3..-1].join('/'))
}

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
    Oneboxer.invalidate(url) if options[:invalidate_oneboxes]
    onebox_raw(url)[:preview]
  end

  def self.onebox(url, options=nil)
    options ||= {}
    Oneboxer.invalidate(url) if options[:invalidate_oneboxes]
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

  def self.oneboxer_exists_for_url?(url)
    Onebox.has_matcher?(url)
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
        if link['href'].present?
          yield link['href'], link
        end
      end
    end

    doc
  end

  def self.apply(string_or_doc)
    doc = string_or_doc
    doc = Nokogiri::HTML::fragment(doc) if doc.is_a?(String)
    changed = false

    Oneboxer.each_onebox_link(doc) do |url, element|
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

  private
  def self.onebox_cache_key(url)
    "onebox__#{url}"
  end

  def self.add_discourse_whitelists
    # Add custom domain whitelists
    if SiteSetting.onebox_domains_whitelist.present?
      domains = SiteSetting.onebox_domains_whitelist.split('|')
      whitelist = Onebox::Engine::WhitelistedGenericOnebox.whitelist
      whitelist.concat(domains)
      whitelist.uniq!
    end
  end

  def self.onebox_raw(url)
    Rails.cache.fetch(onebox_cache_key(url), expires_in: 1.day){
      # This might be able to move to whenever the SiteSetting changes?
      Oneboxer.add_discourse_whitelists

      r = Onebox.preview(url, cache: {}, max_width: 695)
      {
        onebox: r.to_s,
        preview: r.try(:placeholder_html).to_s
      }
    }
  rescue => e
    # no point warning here, just cause we have an issue oneboxing a url
    # we can later hunt for failed oneboxes by searching logs if needed
    Rails.logger.info("Failed to onebox #{url} #{e} #{e.backtrace}")

    # return a blank hash, so rest of the code works
    {preview: "", onebox: ""}
  end

end

