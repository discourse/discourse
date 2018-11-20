#
# HTML emails don't support CSS, so we can use nokogiri to inline attributes based on
# matchers.
#
module Email
  class Styles
    @@plugin_callbacks = []

    attr_accessor :fragment

    delegate :css, to: :fragment

    def initialize(html, opts = nil)
      @html = html
      @opts = opts || {}
      @fragment = Nokogiri::HTML.fragment(@html)
    end

    def self.register_plugin_style(&block)
      @@plugin_callbacks.push(block)
    end

    def add_styles(node, new_styles)
      existing = node['style']
      if existing.present?
        # merge styles
        node['style'] = "#{new_styles}; #{existing}"
      else
        node['style'] = new_styles
      end
    end

    def format_basic
      uri = URI(Discourse.base_url)

      # images
      @fragment.css('img').each do |img|
        next if img['class'] == 'site-logo'

        if (img['class'] && img['class']['emoji']) || (img['src'] && img['src'][/\/_?emoji\//])
          img['width'] = img['height'] = 20
        else
          # use dimensions of original iPhone screen for 'too big, let device rescale'
          if img['width'].to_i > (320) || img['height'].to_i > (480)
            img['width'] = img['height'] = 'auto'
          end
        end

        if img['src']
          # ensure all urls are absolute
          img['src'] = "#{Discourse.base_url}#{img['src']}" if img['src'][/^\/[^\/]/]
          # ensure no schemaless urls
          img['src'] = "#{uri.scheme}:#{img['src']}" if img['src'][/^\/\//]
        end
      end

      # add max-width to big images
      big_images = @fragment.css('img[width="auto"][height="auto"]') -
                   @fragment.css('aside.onebox img') -
                   @fragment.css('img.site-logo, img.emoji')
      big_images.each do |img|
        add_styles(img, 'max-width: 100%;') if img['style'] !~ /max-width/
      end

      # topic featured link
      @fragment.css('a.topic-featured-link').each do |e|
        e['style'] = "color:#858585;padding:2px 8px;border:1px solid #e6e6e6;border-radius:2px;box-shadow:0 1px 3px rgba(0, 0, 0, 0.12), 0 1px 2px rgba(0, 0, 0, 0.24);"
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
      style('.previous-discussion', 'font-size: 17px; color: #444; margin-bottom:10px;')
      style('.notification-date', "text-align:right;color:#999999;padding-right:5px;font-family:'lucida grande',tahoma,verdana,arial,sans-serif;font-size:11px")
      style('.username', "font-size:13px;font-family:'lucida grande',tahoma,verdana,arial,sans-serif;color:#{SiteSetting.email_link_color};text-decoration:none;font-weight:bold")
      style('.user-title', "font-size:13px;font-family:'lucida grande',tahoma,verdana,arial,sans-serif;text-decoration:none;margin-left:7px;color: #999;")
      style('.user-name', "font-size:13px;font-family:'lucida grande',tahoma,verdana,arial,sans-serif;text-decoration:none;margin-left:7px;color: #{SiteSetting.email_link_color};font-weight:normal;")
      style('.post-wrapper', "margin-bottom:25px;")
      style('.user-avatar', 'vertical-align:top;width:55px;')
      style('.user-avatar img', nil, width: '45', height: '45')
      style('hr', 'background-color: #ddd; height: 1px; border: 1px;')
      style('.rtl', 'direction: rtl;')
      style('div.body', 'padding-top:5px;')
      style('.whisper div.body', 'font-style: italic; color: #9c9c9c;')
      style('.lightbox-wrapper .meta', 'display: none')
      correct_first_body_margin
      correct_footer_style
      style('div.undecorated-link-footer a', "font-weight: normal;")
      correct_footer_style_hilight_first
      reset_tables
      onebox_styles
      plugin_styles
    end

    def onebox_styles
      # Links to other topics
      style('aside.quote', 'padding: 12px 25px 2px 12px; margin-bottom: 10px;')
      style('aside.quote div.info-line', 'color: #666; margin: 10px 0')
      style('aside.quote .avatar', 'margin-right: 5px; width:20px; height:20px; vertical-align:middle;')

      style('blockquote', 'border-left: 5px solid #e9e9e9; background-color: #f8f8f8; margin: 0;')
      style('blockquote > p', 'padding: 1em;')

      # Oneboxes
      style('aside.onebox', "border: 5px solid #e9e9e9; padding: 12px 25px 12px 12px;")
      style('aside.onebox header img.site-icon', "width: 16px; height: 16px; margin-right: 3px;")
      style('aside.onebox header a[href]', "color: #222222; text-decoration: none;")
      style('aside.onebox .onebox-body', "clear: both")
      style('aside.onebox .onebox-body img', "max-height: 80%; max-width: 20%; height: auto; float: left; margin-right: 10px;")
      style('aside.onebox .onebox-body h3, aside.onebox .onebox-body h4', "font-size: 1.17em; margin: 10px 0;")
      style('.onebox-metadata', "color: #919191")

      @fragment.css('aside.quote blockquote > p').each do |p|
        p['style'] = 'padding: 0;'
      end

      # Convert all `aside.quote` tags to `blockquote`s
      @fragment.css('aside.quote').each do |n|
        original_node = n.dup
        original_node.search('div.quote-controls').remove
        blockquote = original_node.css('blockquote').inner_html.strip.start_with?("<p") ? original_node.css('blockquote').inner_html : "<p style='padding: 0;'>#{original_node.css('blockquote').inner_html}</p>"
        n.inner_html = original_node.css('div.title').inner_html + blockquote
        n.name = "blockquote"
      end

      # Finally, convert all `aside` tags to `div`s
      @fragment.css('aside, article, header').each do |n|
        n.name = "div"
      end

      # iframes can't go in emails, so replace them with clickable links
      @fragment.css('iframe').each do |i|
        begin
          # sometimes, iframes are blacklisted...
          if i["src"].blank?
            i.remove
            next
          end

          src_uri = URI(i['src'])
          # If an iframe is protocol relative, use SSL when displaying it
          display_src = "#{src_uri.scheme || 'https'}://#{src_uri.host}#{src_uri.path}#{src_uri.query.nil? ? '' : '?' + src_uri.query}#{src_uri.fragment.nil? ? '' : '#' + src_uri.fragment}"
          i.replace "<p><a href='#{src_uri.to_s}'>#{CGI.escapeHTML(display_src)}</a><p>"
        rescue URI::Error
          # If the URL is weird, remove the iframe
          i.remove
        end
      end
    end

    def format_html
      style('.with-accent-colors', "background-color: #{SiteSetting.email_accent_bg_color}; color: #{SiteSetting.email_accent_fg_color};")
      style('h4', 'color: #222;')
      style('h3', 'margin: 15px 0 20px 0;')
      style('hr', 'background-color: #ddd; height: 1px; border: 1px;')
      style('a', "text-decoration: none; font-weight: bold; color: #{SiteSetting.email_link_color};")
      style('ul', 'margin: 0 0 0 10px; padding: 0 0 0 20px;')
      style('li', 'padding-bottom: 10px')
      style('div.footer', 'color:#666; font-size:95%; text-align:center; padding-top:15px;')
      style('span.post-count', 'margin: 0 5px; color: #777;')
      style('pre', 'word-wrap: break-word; max-width: 694px;')
      style('code', 'background-color: #f1f1ff; padding: 2px 5px;')
      style('pre code', 'display: block; background-color: #f1f1ff; padding: 5px;')
      style('.featured-topic a', "text-decoration: none; font-weight: bold; color: #{SiteSetting.email_link_color}; line-height:1.5em;")

      onebox_styles
      plugin_styles

      style('.post-excerpt img', "max-width: 50%; max-height: 400px;")
    end

    # this method is reserved for styles specific to plugin
    def plugin_styles
      @@plugin_callbacks.each { |block| block.call(@fragment, @opts) }
    end

    def to_html
      strip_classes_and_ids
      replace_relative_urls
      @fragment.to_html
    end

    def strip_avatars_and_emojis
      @fragment.search('img').each do |img|
        next unless img['src']

        if img['src'][/_avatar/]
          img.parent['style'] = "vertical-align: top;" if img.parent&.name == 'td'
          img.remove
        end

        if img['title'] && img['src'][/\/_?emoji\//]
          img.add_previous_sibling(img['title'] || "emoji")
          img.remove
        end
      end

      @fragment.to_s
    end

    def make_all_links_absolute
      site_uri = URI(Discourse.base_url)
      @fragment.css("a").each do |link|
        begin
          link["href"] = "#{site_uri}#{link['href']}" unless URI(link["href"].to_s).host.present?
        rescue URI::Error
          # leave it
        end
      end
    end

    private

    def replace_relative_urls
      forum_uri = URI(Discourse.base_url)
      host = forum_uri.host
      scheme = forum_uri.scheme

      @fragment.css('[href]').each do |element|
        href = element['href']
        if href.start_with?("\/\/#{host}")
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

    def correct_footer_style_hilight_first
      footernum = 0
      @fragment.css('.footer.hilight').each do |element|
        linknum = 0
        element.css('a').each do |inner|
          # we want the first footer link to be specially highlighted as IMPORTANT
          if footernum == (0) && linknum == (0)
            bg_color = SiteSetting.email_accent_bg_color
            inner['style'] = "background-color: #{bg_color}; color: #{SiteSetting.email_accent_fg_color}; border-top: 4px solid #{bg_color}; border-right: 6px solid #{bg_color}; border-bottom: 4px solid #{bg_color}; border-left: 6px solid #{bg_color}; display: inline-block; font-weight: bold;"
          end
          return
        end
        return
      end
    end

    def strip_classes_and_ids
      @fragment.css('*').each do |element|
        element.delete('class'.freeze)
        element.delete('id'.freeze)
      end
    end

    def reset_tables
      style('table', nil, cellspacing: '0', cellpadding: '0', border: '0')
    end

    def style(selector, style, attribs = {})
      @fragment.css(selector).each do |element|
        add_styles(element, style) if style
        attribs.each do |k, v|
          element[k] = v
        end
      end
    end
  end
end
