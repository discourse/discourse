require 'open-uri'

require_dependency 'oneboxer/base'
require_dependency 'oneboxer/whitelist'
Dir["#{Rails.root}/lib/oneboxer/*_onebox.rb"].each {|f|
  require_dependency(f.split('/')[-2..-1].join('/'))
}

module Oneboxer
  extend Oneboxer::Base

  Dir["#{Rails.root}/lib/oneboxer/*_onebox.rb"].each do |f|
    add_onebox "Oneboxer::#{Pathname.new(f).basename.to_s.gsub(/\.rb$/, '').classify}".constantize
  end

  def self.default_expiry
    1.month
  end

  # Return a oneboxer for a given URL
  def self.onebox_for_url(url)
    matchers.each do |regexp, oneboxer|
      regexp = regexp.call if regexp.class == Proc
      return oneboxer.new(url) if url =~ regexp
    end
    nil
  end

  # Retrieve the onebox for a url without caching
  def self.onebox_nocache(url)
    oneboxer = onebox_for_url(url)
    return oneboxer.onebox if oneboxer.present?

    whitelist_entry = Whitelist.entry_for_url(url)

    if whitelist_entry.present?
      page_html = open(url).read
      if page_html.present?
        doc = Nokogiri::HTML(page_html)

        if whitelist_entry.allows_oembed?
          # See if if it has an oembed thing we can use
          (doc/"link[@type='application/json+oembed']").each do |oembed|
            return OembedOnebox.new(oembed[:href]).onebox
          end
          (doc/"link[@type='text/json+oembed']").each do |oembed|
            return OembedOnebox.new(oembed[:href]).onebox
          end
        end

        # Check for opengraph
        open_graph = Oneboxer.parse_open_graph(doc)
        return OpenGraphOnebox.new(url, open_graph).onebox if open_graph.present?
      end
    end

    nil
  rescue OpenURI::HTTPError
    nil
  end

  # Parse URLs out of HTML, returning the document when finished.
  def self.each_onebox_link(string_or_doc)
    doc = string_or_doc
    doc = Nokogiri::HTML(doc) if doc.is_a?(String)

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

  def self.create_post_reference(result, args={})
    result.post_onebox_renders.create(post_id: args[:post_id]) if args[:post_id].present?
  rescue ActiveRecord::RecordNotUnique
  end

  def self.render_from_cache(url, args={})
    result = OneboxRender.where(url: url).first

    # Return the result but also create a reference to it
    if result.present?
      create_post_reference(result, args)
      return result
    end
    nil
  end

  # Cache results from a onebox call
  def self.fetch_and_cache(url, args)
    cooked, preview = onebox_nocache(url)
    return nil if cooked.blank?

    # Store a cooked version in the database
    OneboxRender.transaction do
      begin
        render = OneboxRender.create(url: url, preview: preview, cooked: cooked, expires_at: Oneboxer.default_expiry.from_now)
        create_post_reference(render, args)
      rescue ActiveRecord::RecordNotUnique
      end
    end

    [cooked, preview]
  end

  # Retrieve a preview of a onebox, caching the result for performance
  def self.preview(url, args={})
    cached = render_from_cache(url, args) unless args[:no_cache].present?

    # If we have a preview stored, return that. Otherwise return cooked content.
    if cached.present?
      return cached.preview if cached.preview.present?
      return cached.cooked
    end
    cooked, preview = fetch_and_cache(url, args)

    return preview if preview.present?
    cooked
  end

  def self.invalidate(url)
    OneboxRender.destroy_all(url: url)
  end

  # Return the cooked content for a url, caching the result for performance
  def self.onebox(url, args={})

    if args[:invalidate_oneboxes].present?
      # Remove the onebox from the cache
      Oneboxer.invalidate(url)
    else
      cached = render_from_cache(url, args) unless args[:no_cache].present?
      return cached.cooked if cached.present?
    end


    cooked, preview = fetch_and_cache(url, args)
    cooked
  end

end
