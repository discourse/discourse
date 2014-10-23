module UserNotificationsHelper

  def self.sanitize_options
    return @sanitize_options if @sanitize_options
    @sanitize_options = Sanitize::Config::RELAXED.deep_dup
    @sanitize_options[:elements] << 'aside' << 'div'
    @sanitize_options[:attributes][:all] << 'class'
    @sanitize_options
  end

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
    logo_url = SiteSetting.logo_url if logo_url.blank?

    return nil if logo_url.blank?
    if logo_url !~ /http(s)?\:\/\//
      logo_url = "#{Discourse.base_url}#{logo_url}"
    end
    logo_url
  end

  def html_site_link
    "<a href='#{Discourse.base_url}'>#{@site_name}</a>"
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
    # If there's only one post, include the whole thing.
    if posts_count == 1
      raw Sanitize.clean(html, UserNotificationsHelper.sanitize_options)
    else
      # Otherwise, try just the first paragraph.
      para = first_paragraph_from(html)
      raw Sanitize.clean(para.to_s, UserNotificationsHelper.sanitize_options)
    end
  end

  def cooked_post_for_email(post)
    PrettyText.format_for_email(post.cooked).html_safe
  end


  def email_category(category, opts=nil)
    opts = opts || {}

    # If there is no category, bail
    return "" if category.blank?

    # By default hide uncategorized
    return "" if category.uncategorized? && !opts[:show_uncategorized]

    result = ""
    if category.parent_category.present?
      result << "<span style='background-color: ##{category.parent_category.color}; font-size: 12px; padding: 4px 2px; font-weight: bold; margin: 0; width: 2px; white-space:nowrap;'>&nbsp;</span>"
    end
    result << "<span style='background-color: ##{category.color}; color: ##{category.text_color}; font-size: 12px; padding: 4px 6px; font-weight: bold; margin: 0; white-space:nowrap;'>#{category.name}</span>"
    result.html_safe
  end
end
