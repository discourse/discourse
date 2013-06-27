class ExcerptParser < Nokogiri::XML::SAX::Document

  attr_reader :excerpt

  def initialize(length, options=nil)
    @length = length
    @excerpt = ""
    @current_length = 0
    options || {}
    @strip_links = options[:strip_links] == true
    @text_entities = options[:text_entities] == true
    @markdown_images = options[:markdown_images] == true
  end

  def self.get_excerpt(html, length, options)
    me = self.new(length,options)
    parser = Nokogiri::HTML::SAX::Parser.new(me)
    catch(:done) do
      parser.parse(html) unless html.nil?
    end
    me.excerpt.strip!
    me.excerpt
  end

  def include_tag(name, attributes)
    characters("<#{name} #{attributes.map{|k,v| "#{k}='#{v}'"}.join(' ')}>", false, false, false)
  end

  def start_element(name, attributes=[])
    case name
      when "img"

        # If include_images is set, include the image in markdown
        characters("!") if @markdown_images

        attributes = Hash[*attributes.flatten]
        if attributes["alt"]
          characters("[#{attributes["alt"]}]")
        elsif attributes["title"]
          characters("[#{attributes["title"]}]")
        else
          characters("[image]")
        end

        characters("(#{attributes['src']})") if @markdown_images

      when "a"
        unless @strip_links
          include_tag(name, attributes)
          @in_a = true
        end
      when "aside"
        @in_quote = true
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
      characters(" ")
    when "aside"
      @in_quote = false
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
