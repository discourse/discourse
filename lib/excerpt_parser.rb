class ExcerptParser < Nokogiri::XML::SAX::Document

  attr_reader :excerpt

  SPAN_REGEX = /<\s*span[^>]*class\s*=\s*['|"]excerpt['|"][^>]*>/

  def initialize(length, options=nil)
    @length = length
    @excerpt = ""
    @current_length = 0
    options || {}
    @strip_links = options[:strip_links] == true
    @text_entities = options[:text_entities] == true
    @markdown_images = options[:markdown_images] == true
    @keep_newlines = options[:keep_newlines] == true
    @keep_emojis = options[:keep_emojis] == true
    @start_excerpt = false
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
    characters("<#{name} #{attributes.map{|k,v| "#{k}=\"#{escape_attribute(v)}\""}.join(' ')}>", false, false, false)
  end

  def start_element(name, attributes=[])
    case name
      when "img"

        attributes = Hash[*attributes.flatten]

        if @keep_emojis && attributes["class"] == 'emoji'
          return include_tag(name, attributes)
        end

        # If include_images is set, include the image in markdown
        characters("!") if @markdown_images

        if attributes["alt"]
          characters("[#{attributes["alt"]}]")
        elsif attributes["title"]
          characters("[#{attributes["title"]}]")
        else
          characters("[#{I18n.t 'excerpt_image'}]")
        end

        characters("(#{attributes['src']})") if @markdown_images

      when "a"
        unless @strip_links
          include_tag(name, attributes)
          @in_a = true
        end

      when "aside"
        @in_quote = true

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
    end
  end

  def end_element(name)
    case name
    when "a"
      unless @strip_links
        characters("</a>",false, false, false)
        @in_a = false
      end
    when "p", "br"
      if @keep_newlines
        characters("<br>", false, false, false)
      else
        characters(" ")
      end
    when "aside"
      @in_quote = false
    when "div", "span"
      throw :done if @start_excerpt
      characters("</span>", false, false, false) if @in_spoiler
      @in_spoiler = false
    end
  end

  def characters(string, truncate = true, count_it = true, encode = true)
    return if @in_quote
    encode = encode ? lambda{|s| ERB::Util.html_escape(s)} : lambda {|s| s}
    if count_it && @current_length + string.length > @length
      length = [0, @length - @current_length - 1].max
      @excerpt << encode.call(string[0..length]) if truncate
      @excerpt << (@text_entities ? "..." : "&hellip;")
      @excerpt << "</a>" if @in_a
      throw :done
    end
    @excerpt << encode.call(string)
    @current_length += string.length if count_it
  end
end
