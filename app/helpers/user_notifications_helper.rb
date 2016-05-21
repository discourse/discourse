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
    logo_url = SiteSetting.digest_logo_url
    logo_url = SiteSetting.logo_url if logo_url.blank? || logo_url =~ /\.svg$/i

    return nil if logo_url.blank? || logo_url =~ /\.svg$/i
    if logo_url !~ /http(s)?\:\/\//
      logo_url = "#{Discourse.base_url}#{logo_url}"
    end
    logo_url
  end

  def html_site_link(color)
    "<a href='#{Discourse.base_url}' style='color: ##{color}'>#{@site_name}</a>"
  end

  def first_paragraph_from(html)
    doc = Nokogiri::HTML(html)

    result = ""
    doc.css('p').each do |p|
      if p.text.present?
        result << p.to_s
        return result if result.size >= 100
      end
    end
    return result unless result.blank?

    # If there is no first paragaph, return the first div (onebox)
    doc.css('div').first
  end

  def email_excerpt(html, posts_count)
    # only include 1st paragraph when more than 1 posts
    html = first_paragraph_from(html).to_s if posts_count > 1
    PrettyText.format_for_email(html).html_safe
  end

  def normalize_name(name)
    name.downcase.gsub(/[\s_-]/, '')
  end

  def show_name_on_post(post)
    SiteSetting.enable_names? &&
      SiteSetting.display_name_on_posts? &&
      post.user.name.present? &&
      normalize_name(post.user.name) != normalize_name(post.user.username)
  end

  def format_for_email(post, use_excerpt, style = nil)
    html = use_excerpt ? post.excerpt : post.cooked
    PrettyText.format_for_email(html, post, style).html_safe
  end

end
