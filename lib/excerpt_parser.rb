# frozen_string_literal: true

class ExcerptParser < Nokogiri::XML::SAX::Document
  attr_reader :excerpt

  CUSTOM_EXCERPT_REGEX = /<\s*(span|div)[^>]*class\s*=\s*['"]excerpt['"][^>]*>/

  def initialize(length, options = nil)
    @length = length
    @excerpt = +""
    @current_length = 0
    options || {}
    @strip_links = options[:strip_links] == true
    @strip_images = options[:strip_images] == true
    @text_entities = options[:text_entities] == true
    @markdown_images = options[:markdown_images] == true
    @keep_newlines = options[:keep_newlines] == true
    @keep_emoji_images = options[:keep_emoji_images] == true
    @keep_onebox_source = options[:keep_onebox_source] == true
    @keep_onebox_body = options[:keep_onebox_body] == true
    @keep_quotes = options[:keep_quotes] == true
    @keep_svg = options[:keep_svg] == true
    @remap_emoji = options[:remap_emoji] == true
    @start_excerpt = false
    @start_hashtag_icon = false
    @in_details_depth = 0
  end

  def self.get_excerpt(html, length, options)
    length = html.length if html.include?("excerpt") && CUSTOM_EXCERPT_REGEX === html
    me = self.new(length, options)
    parser = Nokogiri::HTML4::SAX::Parser.new(me, Encoding::UTF_8)
    catch(:done) { parser.parse(html) }
    excerpt = me.excerpt.strip
    excerpt = excerpt.gsub(/\s*\n+\s*/, "\n\n") if options[:keep_onebox_source] ||
      options[:keep_onebox_body]
    excerpt = CGI.unescapeHTML(excerpt) if options[:text_entities] == true
    excerpt
  end

  def escape_attribute(v)
    return "" unless v

    v = v.dup
    v.gsub!("&", "&amp;")
    v.gsub!("\"", "&#34;")
    v.gsub!("<", "&lt;")
    v.gsub!(">", "&gt;")
    v
  end

  def include_tag(name, attributes)
    characters(
      "<#{name} #{attributes.map { |k, v| "#{k}=\"#{escape_attribute(v)}\"" }.join(" ")}>",
      truncate: false,
      count_it: false,
      encode: false,
    )
  end

  def start_element(name, attributes = [])
    case name
    when "img"
      attributes = Hash[*attributes.flatten]

      if attributes["class"]&.include?("emoji")
        if @remap_emoji
          title = (attributes["alt"] || "").gsub(":", "")
          title = Emoji.lookup_unicode(title) || attributes["alt"]
          return characters(title)
        elsif @keep_emoji_images
          return include_tag(name, attributes)
        else
          return characters(attributes["alt"])
        end
      end

      unless @strip_images
        # If include_images is set, include the image in markdown
        characters("!") if @markdown_images

        if !attributes["alt"].blank?
          characters("[#{attributes["alt"]}]")
        elsif !attributes["title"].blank?
          characters("[#{attributes["title"]}]")
        else
          characters("[#{I18n.t "excerpt_image"}]")
        end

        characters("(#{attributes["src"]})") if @markdown_images
      end
    when "a"
      unless @strip_links
        include_tag(name, attributes)
        @in_a = true
      end
    when "aside"
      attributes = Hash[*attributes.flatten]
      if !(@keep_onebox_source || @keep_onebox_body) || !attributes["class"]&.include?("onebox")
        @in_quote = true
      end

      if attributes["class"]&.include?("quote")
        if @keep_quotes || (@keep_onebox_body && attributes["data-topic"].present?)
          @in_quote = false
        end
      end
    when "article"
      @in_quote = !@keep_onebox_body if attributes.include?(%w[class onebox-body])
    when "header"
      @in_quote = !@keep_onebox_source if attributes.include?(%w[class source])
    when "div", "span"
      attributes = Hash[*attributes.flatten]

      # Only match "excerpt" class if it does not specifically equal "excerpt
      # hidden" in order to prevent internal links with GitHub oneboxes from
      # being empty https://meta.discourse.org/t/269436
      if attributes["class"]&.include?("excerpt") && !attributes["class"]&.match?("excerpt hidden")
        @excerpt = +""
        @current_length = 0
        @start_excerpt = true
      elsif attributes["class"]&.include?("hashtag-icon-placeholder")
        @start_hashtag_icon = true
        include_tag(name, attributes)
      end
    when "details"
      @in_details_depth += 1
    when "summary"
      if @in_details_depth == 1 && !@in_summary
        @in_summary = true
        characters("▶ ", truncate: false, count_it: false, encode: false)
      end
    when "svg"
      attributes = Hash[*attributes.flatten]
      if attributes["class"]&.include?("d-icon") && @keep_svg
        include_tag(name, attributes)
        @in_svg = true
      end
    when "use"
      include_tag(name, attributes) if @in_svg && @keep_svg
    end
  end

  def end_element(name)
    case name
    when "a"
      unless @strip_links
        characters("</a>", truncate: false, count_it: false, encode: false)
        @in_a = false
      end
    when "p", "br"
      if @keep_newlines
        characters("<br>", truncate: false, count_it: false, encode: false)
      else
        characters(" ")
      end
    when "aside"
      @in_quote = false
    when "details"
      @in_details_depth -= 1
    when "summary"
      @in_summary = false if @in_details_depth == 1
    when "div", "span"
      throw :done if @start_excerpt
      characters("</span>", truncate: false, count_it: false, encode: false) if @start_hashtag_icon
    when "svg"
      characters("</svg>", truncate: false, count_it: false, encode: false) if @keep_svg
      @in_svg = false
    when "use"
      characters("</use>", truncate: false, count_it: false, encode: false) if @keep_svg
    end
  end

  def clean(str)
    ERB::Util.html_escape(str.strip)
  end

  def characters(
    string,
    truncate: true,
    count_it: true,
    encode: true,
    before_string: nil,
    after_string: nil
  )
    return if @in_quote || @in_details_depth > 1 || (@in_details_depth == 1 && !@in_summary)

    # we call length on this so might as well ensure we have a string
    string = string.to_s

    @excerpt << before_string if before_string

    encode = encode ? lambda { |s| ERB::Util.html_escape(s) } : lambda { |s| s }
    if count_it && @current_length + string.length > @length
      length = [0, @length - @current_length - 1].max
      @excerpt << encode.call(string[0..length]) if truncate && !emoji?(string)
      @excerpt << (@text_entities ? "..." : "&hellip;")
      @excerpt << "</a>" if @in_a
      @excerpt << after_string if after_string
      throw :done
    end

    @excerpt << encode.call(string)
    @excerpt << after_string if after_string
    @current_length += string.length if count_it
  end

  def emoji?(string)
    string.match?(/\A:\w+:\Z/)
  end
end
