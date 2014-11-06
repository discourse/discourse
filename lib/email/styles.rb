#
# HTML emails don't support CSS, so we can use nokogiri to inline attributes based on
# matchers.
#
module Email
  class Styles
    @@plugin_callbacks = []

    def initialize(html)
      @html = html
      @fragment = Nokogiri::HTML.fragment(@html)
    end

    def self.register_plugin_style(&block)
      @@plugin_callbacks.push(block)
    end

    def add_styles(node, new_styles)
      existing = node['style']
      if existing.present?
        node['style'] = "#{existing}; #{new_styles}"
      else
        node['style'] = new_styles
      end
    end

    def format_basic
      uri = URI(Discourse.base_url)

      # images
      @fragment.css('img').each do |img|

        next if img['class'] == 'site-logo'

        if img['class'] == "emoji" || img['src'] =~ /plugins\/emoji/
          img['width'] = 20
          img['height'] = 20
        else
          # having no extra style on email images might work best?
          img['width'] = 'auto'
          img['height'] = 'auto'
          add_styles(img, 'max-width:100%;') if img['style'] !~ /max-width/
        end

        # ensure all urls are absolute
        if img['src'] =~ /^\/[^\/]/
          img['src'] = "#{Discourse.base_url}#{img['src']}"
        end

        # ensure no schemaless urls
        if img['src'] && img['src'].starts_with?("//")
          img['src'] = "#{uri.scheme}:#{img['src']}"
        end
      end

      # attachments
      @fragment.css('a.attachment').each do |a|

        # ensure all urls are absolute
        if a['href'] =~ /^\/[^\/]/
          a['href'] = "#{Discourse.base_url}#{a['href']}"
        end

        # ensure no schemaless urls
        if a['href'] && a['href'].starts_with?("//")
          a['href'] = "#{uri.scheme}:#{a['href']}"
        end
      end
    end

    def format_notification
      style('.previous-discussion', 'font-size: 17px; color: #444;')
      style('.notification-date', "text-align:right;color:#999999;padding-right:5px;font-family:'lucida grande',tahoma,verdana,arial,sans-serif;font-size:11px")
      style('.username', "font-size:13px;font-family:'lucida grande',tahoma,verdana,arial,sans-serif;color:#3b5998;text-decoration:none;font-weight:bold")
      style('.post-wrapper', "margin-bottom:25px;")
      style('.user-avatar', 'vertical-align:top;width:55px;')
      style('.user-avatar img', nil, width: '45', height: '45')
      style('hr', 'background-color: #ddd; height: 1px; border: 1px;')
      style('.rtl', 'direction: rtl;')
      style('td.body', 'padding-top:5px;', colspan: "2")
      correct_first_body_margin
      correct_footer_style
      reset_tables
      onebox_styles
      plugin_styles
    end

    def onebox_styles
      # Links to other topics
      style('aside.quote', 'border-left: 5px solid #bebebe; background-color: #f1f1f1; padding: 12px 25px 2px 12px; margin-bottom: 10px;')
      style('aside.quote blockquote', 'border: 0px; padding: 0; margin: 7px 0')
      style('aside.quote div.info-line', 'color: #666; margin: 10px 0')
      style('aside.quote .avatar', 'margin-right: 5px; width:20px; height:20px')

      # Oneboxes
      style('aside.onebox', "padding: 12px 25px 2px 12px; border-left: 5px solid #bebebe; background: #eee; margin-bottom: 10px;")
      style('aside.onebox img', "max-height: 80%; max-width: 25%; height: auto; float: left; margin-right: 10px; margin-bottom: 10px")
      style('aside.onebox h3', "border-bottom: 0")
      style('aside.onebox .source', "margin-bottom: 8px")
      style('aside.onebox .source a[href]', "color: #333; font-weight: normal")
      style('aside.clearfix', "clear: both")

      # Finally, convert all `aside` tags to `div`s
      @fragment.css('aside, article, header').each do |n|
        n.name = "div"
      end

      # iframes can't go in emails, so replace them with clickable links
      @fragment.css('iframe').each do |i|
        begin
          src_uri = URI(i['src'])

          # If an iframe is protocol relative, use SSL when displaying it
          display_src = "#{src_uri.scheme || 'https://'}#{src_uri.host}#{src_uri.path}"
          i.replace "<p><a href='#{src_uri.to_s}'>#{display_src}</a><p>"
        rescue URI::InvalidURIError
          # If the URL is weird, remove it
          i.remove
        end
      end
    end

    def format_html
      style('h3', 'margin: 15px 0 20px 0;')
      style('hr', 'background-color: #ddd; height: 1px; border: 1px;')
      style('a', 'text-decoration: none; font-weight: bold; color: #006699;')
      style('ul', 'margin: 0 0 0 10px; padding: 0 0 0 20px;')
      style('li', 'padding-bottom: 10px')
      style('div.digest-post', 'margin-left: 15px; margin-top: 20px; max-width: 694px;')
      style('div.digest-post h1', 'font-size: 20px;')
      style('span.footer-notice', 'color:#666; font-size:80%')
      style('span.post-count', 'margin: 0 5px; color: #777;')
      style('pre', 'word-wrap: break-word; max-width: 694px;')
      style('code', 'background-color: #f1f1ff; padding: 2px 5px;')
      style('pre code', 'display: block; background-color: #f1f1ff; padding: 5px;')
      style('.featured-topic a', 'text-decoration: none; font-weight: bold; color: #006699; margin-right: 5px')

      onebox_styles
      plugin_styles
    end

    # this method is reserved for styles specific to plugin
    def plugin_styles
      @@plugin_callbacks.each { |block| block.call(@fragment) }
    end

    def to_html
      strip_classes_and_ids
      replace_relative_urls
      @fragment.to_html.tap do |result|
        result.gsub!(/\[email-indent\]/, "<div style='margin-left: 15px'>")
        result.gsub!(/\[\/email-indent\]/, "</div>")
      end
    end

    def strip_avatars_and_emojis
      @fragment.css('img').each do |img|
        if img['src'] =~ /_avatar/
          img.parent['style'] = "vertical-align: top;" if img.parent.name == 'td'
          img.remove
        end

        if img['src'] =~ /plugins\/emoji/
          img.replace img['title']
        end
      end
      return @fragment.to_s
    end

    private

    def replace_relative_urls
      forum_uri = URI(Discourse.base_url)
      host = forum_uri.host
      scheme = forum_uri.scheme

      @fragment.css('[href]').each do |element|
        href = element['href']
        if href =~ /^\/\/#{host}/
          element['href'] = "#{scheme}:#{href}"
        end
      end
    end

    def correct_first_body_margin
      @fragment.css('.body p').each do |element|
        element['style'] = "margin-top:0; border: 0;"
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
      style('table', nil, cellspacing: '0', cellpadding: '0', border: '0')
    end

    def style(selector, style, attribs = {})
      @fragment.css(selector).each do |element|
        add_styles(element, style) if style
        attribs.each do |k,v|
          element[k] = v
        end
      end
    end
  end
end
