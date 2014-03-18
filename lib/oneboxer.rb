
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
    onebox_raw(url).placeholder_html
  end

  def self.onebox(url, options=nil)
    options ||= {}
    Oneboxer.invalidate(url) if options[:invalidate_oneboxes]
    onebox_raw(url).to_s
  end

  def self.cached_onebox(url)
    Rails.cache.read(onebox_cache_key(url))
      .to_s
  end

  def self.cached_preview(url)
    Rails.cache.read(onebox_cache_key(url))
      .try(:placeholder_html)
      .to_s
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
      onebox, preview = yield(url,element)
      if onebox
        parsed_onebox = Nokogiri::HTML::fragment(onebox)
        next unless parsed_onebox.children.count > 0

        # special logic to strip empty p elements
        if  element.parent &&
            element.parent.node_name.downcase == "p" &&
            element.parent.children.count == 1 &&
            parsed_onebox.children.first.name.downcase == "div"
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
    "onebox_#{url}"
  end

  def self.onebox_raw(url)
    Rails.cache.fetch(onebox_cache_key(url)){
      Onebox.preview(url, cache: {})
    }
  end

end

