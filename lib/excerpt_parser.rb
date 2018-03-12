class ExcerptParser < Nokogiri::XML::SAX::Document

  attr_reader :excerpt

  SPAN_REGEX = /<\s*span[^>]*class\s*=\s*['|"]excerpt['|"][^>]*>/

  def initialize(length, options = nil)
    @length = length
    @excerpt = ""
    @current_length = 0
    options || {}
    @strip_links = options[:strip_links] == true
    @strip_images = options[:strip_images] == true
    @text_entities = options[:text_entities] == true
    @markdown_images = options[:markdown_images] == true
    @keep_newlines = options[:keep_newlines] == true
    @keep_emoji_images = options[:keep_emoji_images] == true
    @keep_onebox_source = options[:keep_onebox_source] == true
    @remap_emoji = options[:remap_emoji] == true
    @start_excerpt = false
    @in_details_depth = 0
    @summary_contents = ""
    @detail_contents = ""
  end

  def self.get_excerpt(html, length, options)
    html ||= ''
    length = html.length if html.include?('excerpt') && SPAN_REGEX === html
    me = self.new(length, options)
    parser = Nokogiri::HTML::SAX::Parser.new(me)
    catch(:done) do
      parser.parse(html)
    end
    excerpt = me.excerpt.strip
    excerpt = excerpt.gsub(/\s*\n+\s*/, "\n\n") if options[:keep_onebox_source]
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
    characters("<#{name} #{attributes.map { |k, v| "#{k}=\"#{escape_attribute(v)}\"" }.join(' ')}>",
               truncate: false, count_it: false, encode: false)
  end

  def start_element(name, attributes = [])
    case name
    when "img"
      attributes = Hash[*attributes.flatten]

      if attributes["class"]&.include?('emoji')
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
          characters("[#{I18n.t 'excerpt_image'}]")
        end

        characters("(#{attributes['src']})") if @markdown_images
      end

    when "a"
      unless @strip_links
        include_tag(name, attributes)
        @in_a = true
      end

    when "aside"
      attributes = Hash[*attributes.flatten]
      unless @keep_onebox_source && attributes['class'].include?('onebox')
        @in_quote = true
      end

    when 'article'
      if @keep_onebox_source && attributes.include?(['class', 'onebox-body'])
        @in_quote = true
      end

    when "div", "span"
      if attributes.include?(["class", "excerpt"])
        @excerpt = ""
        @current_length = 0
        @start_excerpt = true
      end
      # Preserve spoilers
      if attributes.include?(["class", "spoiler"])
        include_tag("span", attributes)
        @in_spoiler = true
      end

    when "details"
      @detail_contents = "" if @in_details_depth == 0
      @in_details_depth += 1

    when "summary"
      if @in_details_depth == 1 && !@in_summary
        @summary_contents = ""
        @in_summary = true
      end

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
      if @in_details_depth == 0
        @summary_contents = clean(@summary_contents)
        @detail_contents = clean(@detail_contents)

        if @current_length + @summary_contents.length >= @length
          characters(@summary_contents,
                     encode: false,
                     before_string: "<details class='disabled'><summary>",
                     after_string: "</summary></details>")
        else
          characters(@summary_contents,
                     truncate: false,
                     encode: false,
                     before_string: "<details><summary>",
                     after_string: "</summary>")

          characters(@detail_contents,
                     encode: false,
                     after_string: "</details>")
        end
      end
    when "summary"
      @in_summary = false if @in_details_depth == 1
    when "div", "span"
      throw :done if @start_excerpt
      characters("</span>", truncate: false, count_it: false, encode: false) if @in_spoiler
      @in_spoiler = false
    end
  end

  def clean(str)
    ERB::Util.html_escape(str.strip)
  end

  def characters(string, truncate: true, count_it: true, encode: true, before_string: nil, after_string: nil)
    return if @in_quote

    # we call length on this so might as well ensure we have a string
    string = string.to_s
    if @in_details_depth > 0
      if @in_summary
        @summary_contents << string
      else
        @detail_contents << string
      end
      return
    end

    @excerpt << before_string if before_string

    encode = encode ? lambda { |s| ERB::Util.html_escape(s) } : lambda { |s| s }
    if count_it && @current_length + string.length > @length
      length = [0, @length - @current_length - 1].max
      @excerpt << encode.call(string[0..length]) if truncate
      @excerpt << (@text_entities ? "..." : "&hellip;")
      @excerpt << "</a>" if @in_a
      @excerpt << after_string if after_string
      throw :done
    end

    @excerpt << encode.call(string)
    @excerpt << after_string if after_string
    @current_length += string.length if count_it
  end
end
