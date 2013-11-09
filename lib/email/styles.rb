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
          img['width'] = 20
          img['height'] = 20
        else
          img['style'] = "max-width: 694px;"
        end

        # ensure all urls are absolute
        if img['src'] =~ /^\/[^\/]/
          img['src'] = "#{Discourse.base_url}#{img['src']}"
        end

        # ensure no schemaless urls
        if img['src'].starts_with?("//")
          img['src'] = "http:" + img['src']
        end
      end
    end

    def format_notification
      style('.previous-discussion', 'font-size: 17px; color: #444;')
      style('.date', "text-align:right;color:#999999;padding-right:5px;font-family:'lucida grande',tahoma,verdana,arial,sans-serif;font-size:11px")
      style('.username', "font-size:13px;font-family:'lucida grande',tahoma,verdana,arial,sans-serif;color:#3b5998;text-decoration:none;font-weight:bold")
      style('.post-wrapper', "margin-bottom:25px;max-width:761px")
      style('.user-avatar', 'vertical-align:top;width:55px;')
      style('.user-avatar img', nil, width: '45', height: '45')
      style('hr', 'background-color: #ddd; height: 1px; border: 1px;')
      # we can do this but it does not look right
      # style('#main', 'font-family:"Helvetica Neue", Helvetica, Arial, sans-serif')
      style('td.body', 'padding-top:5px;', colspan: "2")
      correct_first_body_margin
      correct_footer_style
      reset_tables
    end

    def format_html
      style('h3', 'margin: 15px 0 20px 0; border-bottom: 1px solid #ddd;')
      style('hr', 'background-color: #ddd; height: 1px; border: 1px;')
      style('a',' text-decoration: none; font-weight: bold; color: #006699;')
      style('ul', 'margin: 0 0 0 10px; padding: 0 0 0 20px;')
      style('li', 'padding-bottom: 10px')
      style('div.digest-post', 'margin-left: 15px; margin-top: 20px; max-width: 694px;')
      style('div.digest-post h1', 'font-size: 20px;')
      style('span.footer-notice', 'color:#666; font-size:80%')

      @fragment.css('pre').each do |pre|
        pre.replace(pre.text)
      end

    end

    def to_html
      strip_classes_and_ids
      @fragment.to_html.tap do |result|
        result.gsub!(/\[email-indent\]/, "<div style='margin-left: 15px'>")
        result.gsub!(/\[\/email-indent\]/, "</div>")
      end
    end

    private

    def correct_first_body_margin
      @fragment.css('.body p').each do |element|
        element['style'] = "margin-top:0;"
      end
    end

    def correct_footer_style
      @fragment.css('.footer').each do |element|
        element['style'] = "color:#666;"
        element.css('a').each do |inner|
          inner['style'] = "color:#666;"
        end
      end
    end

    def strip_classes_and_ids
      @fragment.css('*').each do |element|
        element.delete('class')
        element.delete('id')
      end
    end

    def reset_tables
      style('table',nil, cellspacing: '0', cellpadding: '0', border: '0')
    end

    def style(selector, style, attribs = {})
      @fragment.css(selector).each do |element|
        element['style'] = style if style
        attribs.each do |k,v|
          element[k] = v
        end
      end
    end
  end
end
