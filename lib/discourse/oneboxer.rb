require "open-uri"
require "multi_json"
require "nokogiri"
require "mustache"
require "discourse/oneboxer/version"

require_relative "oneboxer/base"
require_relative "oneboxer/whitelist"
require_relative "oneboxer/base_onebox"
require_relative "oneboxer/handlebars_onebox"
require_relative "oneboxer/oembed_onebox"
require_relative "oneboxer/amazon_onebox"
require_relative "oneboxer/android_app_store_onebox"
require_relative "oneboxer/apple_app_onebox"
require_relative "oneboxer/bliptv_onebox"
require_relative "oneboxer/clikthrough_onebox"
require_relative "oneboxer/college_humor_onebox"
require_relative "oneboxer/dailymotion_onebox"
require_relative "oneboxer/discourse_local_onebox"
require_relative "oneboxer/dotsub_onebox"
require_relative "oneboxer/flickr_onebox"
require_relative "oneboxer/funny_or_die_onebox"
require_relative "oneboxer/gist_onebox"
require_relative "oneboxer/github_blob_onebox"
require_relative "oneboxer/github_commit_onebox"
require_relative "oneboxer/github_pullrequest_onebox"
require_relative "oneboxer/hulu_onebox"
require_relative "oneboxer/image_onebox"
require_relative "oneboxer/imgur_onebox"
require_relative "oneboxer/kinomap_onebox"
require_relative "oneboxer/nfb_onebox"
require_relative "oneboxer/open_graph_onebox"
require_relative "oneboxer/qik_onebox"
require_relative "oneboxer/revision_onebox"
require_relative "oneboxer/rottentomatoes_onebox"
require_relative "oneboxer/slideshare_oneboxer"
require_relative "oneboxer/smugmug_onebox"
require_relative "oneboxer/soundcloud_onebox"
require_relative "oneboxer/stack_exchange_onebox"
require_relative "oneboxer/ted_onebox"
require_relative "oneboxer/twitter_onebox"
require_relative "oneboxer/version"
require_relative "oneboxer/viddler_onebox"
require_relative "oneboxer/video_onebox"
require_relative "oneboxer/vimeo_onebox"
require_relative "oneboxer/wikipedia_onebox"
require_relative "oneboxer/yfrog_onebox"



module Discourse
  module Oneboxer
	  extend Oneboxer::Base

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

	  # lazy add oneboxing
	  add_onebox AmazonOnebox
		add_onebox AndroidAppStoreOnebox
		add_onebox AppleAppOnebox
		add_onebox BaseOnebox
		add_onebox BliptvOnebox
		add_onebox ClikthroughOnebox
		add_onebox CollegeHumorOnebox
		add_onebox DailymotionOnebox
		add_onebox DiscourseLocalOnebox
		add_onebox DotsubOnebox
		add_onebox FlickrOnebox
		add_onebox FunnyOrDieOnebox
		add_onebox GistOnebox
		add_onebox GithubBlobOnebox
		add_onebox GithubCommitOnebox
		add_onebox GithubPullrequestOnebox
		add_onebox HandlebarsOnebox
		add_onebox HuluOnebox
		add_onebox ImageOnebox
		add_onebox ImgurOnebox
		add_onebox KinomapOnebox
		add_onebox NfbOnebox
		add_onebox OembedOnebox
		add_onebox OpenGraphOnebox
		add_onebox QikOnebox
		add_onebox RevisionOnebox
		add_onebox RottentomatoesOnebox
		add_onebox SlideshareOnebox
		add_onebox SmugmugOnebox
		add_onebox SoundcloudOnebox
		add_onebox StackExchangeOnebox
		add_onebox TedOnebox
		add_onebox TwitterOnebox
		add_onebox ViddlerOnebox
		add_onebox VideoOnebox
		add_onebox VimeoOnebox
		add_onebox WikipediaOnebox
		add_onebox YfrogOnebox

	  def self.default_expiry
	    1.day
	  end

	  # Return a oneboxer for a given URL
	  def self.onebox_for_url(url)
	    matchers.each do |matcher|
	      regexp = matcher.regexp
	      klass = matcher.klass

	      regexp = regexp.call if regexp.class == Proc
	      return klass.new(url) if url =~ regexp
	    end
	    nil
	  end

	  # Retrieve the onebox for a url without caching
	  def self.onebox_nocache(url)
	    oneboxer = onebox_for_url(url)
	    return oneboxer.onebox unless oneboxer.nil?

	    whitelist_entry = Whitelist.entry_for_url(url)

	    if whitelist_entry.present?
	      # TODO - only download HEAD section
	      # TODO - sane timeout
	      # TODO - FAIL if for any reason you are downloading more that 5000 bytes
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
	    doc = Nokogiri::HTML::fragment(doc) if doc.is_a?(String)

	    onebox_links = doc.search("a.onebox")
	    if onebox_links.nil? || onebox_links.empty?
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

	  def self.cache_key_for(url)
	    "onebox:#{Digest::SHA1.hexdigest(url)}"
	  end

	  def self.preview_cache_key_for(url)
	    "onebox:preview:#{Digest::SHA1.hexdigest(url)}"
	  end

	  def self.render_from_cache(url)
	    Rails.cache.read(cache_key_for(url))
	  end

	  # Cache results from a onebox call
	  def self.fetch_and_cache(url, args)
	    contents, preview = onebox_nocache(url)
	    return nil if contents.blank?

	    Rails.cache.write(cache_key_for(url), contents, expires_in: default_expiry)
	    if preview.present?
	      Rails.cache.write(preview_cache_key_for(url), preview, expires_in: default_expiry)
	    end

	    [contents, preview]
	  end

	  def self.invalidate(url)
	    Rails.cache.delete(cache_key_for(url))
	  end

	  def self.preview(url, args={})
	    # Look for a preview
	    cached = Rails.cache.read(preview_cache_key_for(url)) unless args[:no_cache].present?
	    return cached if cached.present?

	    # Try the full version
	    cached = render_from_cache(url)
	    return cached if cached.present?

	    # If that fails, look it up
	    contents, cached = fetch_and_cache(url, args)
	    return cached if cached.present?
	    contents
	  end

	  # Return the cooked content for a url, caching the result for performance
	  def self.onebox(url, args={})

	    if args[:invalidate_oneboxes]
	      # Remove the onebox from the cache
	      Oneboxer.invalidate(url)
	    else
	      contents = render_from_cache(url)
	      return contents unless contents.nil?
	    end

	    fetch_and_cache(url, args)
	  end

	end
end
