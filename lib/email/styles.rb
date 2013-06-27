#
# HTML emails don't support CSS, so we can use nokogiri to inline attributes based on
# matchers.
#
module Email
  class Styles

    def initialize(html)
      @html = html
      @fragment = Nokogiri::HTML.fragment(@html)
    end

    def format_basic
      @fragment.css('img').each do |img|

        if img['src'] =~ /\/assets\/emoji\//
          img['style'] = "width: 20px; height: 20px;"
        else
          img['style'] = "max-width: 694px;"
        end

        if img['src'][0] == "/"
          img['src'] = "#{Discourse.base_url}#{img['src']}"
        end

      end
    end

    def format_html
      @fragment.css('h3').each do |h3|
        h3['style'] = 'margin: 15px 0 20px 0; border-bottom: 1px solid #ddd;'
      end

      @fragment.css('hr').each do |hr|
        hr['style'] = 'background-color: #ddd; height: 1px; border: 1px;'
      end


      @fragment.css('a').each do |a|
        a['style'] = 'text-decoration: none; font-weight: bold; font-size: 15px; color: #006699;'
      end

      @fragment.css('ul').each do |ul|
        ul['style'] = 'margin: 0 0 0 10px; padding: 0 0 0 20px;'
      end

      @fragment.css('li').each do |li|
        li['style'] = 'padding-bottom: 10px'
      end

      @fragment.css('pre').each do |pre|
        pre.replace(pre.text)
      end

      @fragment.css('div.digest-post').each do |div|
        div['style'] = 'margin-left: 15px; margin-top: 20px; max-width: 694px;'
      end
    end

    def to_html
      @fragment.to_html
    end


  end
end