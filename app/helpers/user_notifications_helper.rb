module UserNotificationsHelper

  def indent(text, by=2)
    spacer = " " * by
    result = ""
    text.each_line do |line|
      result << spacer << line
    end
    result
  end

  def correct_top_margin(html, desired)
    fragment = Nokogiri::HTML.fragment(html)
    if para = fragment.css("p:first").first
      para["style"] = "margin-top: #{desired};"
    end
    fragment.to_html.html_safe
  end

  def logo_url
    logo_url = SiteSetting.logo_url
    if logo_url !~ /http(s)?\:\/\//
      logo_url = "#{Discourse.base_url}#{logo_url}"
    end
    logo_url
  end

  def html_site_link
    "<a href='#{Discourse.base_url}'>#{@site_name}</a>"
  end

  def email_excerpt(html, posts_count)
    # If there's only one post, include the whole thing.
    if posts_count == 1
      return raw Sanitize.clean(html, Sanitize::Config::RELAXED)
    else
      # Otherwise, try just the first paragraph.
      first_paragraph = Nokogiri::HTML(html).at('p')
      return raw Sanitize.clean(first_paragraph.to_s, Sanitize::Config::RELAXED)
    end
  end
end
