class ExcerptParser < Nokogiri::XML::SAX::Document

  attr_reader :excerpt

  def initialize(length,options)
    @length = length
    @excerpt = ""
    @current_length = 0
    @strip_links = options[:strip_links] == true
  end

  def self.get_excerpt(html, length, options)
    me = self.new(length,options)
    parser = Nokogiri::HTML::SAX::Parser.new(me)
    catch(:done) do
      parser.parse(html) unless html.nil?
    end
    me.excerpt
  end

  def start_element(name, attributes=[])
    case name
      when "img"
        attributes = Hash[*attributes.flatten]
        if attributes["alt"]
          characters("[#{attributes["alt"]}]")
        elsif attributes["title"]
          characters("[#{attributes["title"]}]")
        else
          characters("[image]")
        end
      when "a"
        unless @strip_links
          c = "<a "
          c << attributes.map{|k,v| "#{k}='#{v}'"}.join(' ')
          c << ">"
          characters(c, false, false, false)
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
      @excerpt << "&hellip;"
      @excerpt << "</a>" if @in_a
      throw :done
    end
    @excerpt << encode.call(string)
    @current_length += string.length if count_it
  end
end
