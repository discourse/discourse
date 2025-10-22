# frozen_string_literal: true

module UserNotificationsHelper
  include GlobalPath

  def indent(text, by = 2)
    spacer = " " * by
    result = +""
    text.each_line { |line| result << spacer << line }
    result
  end

  def correct_top_margin(html, desired)
    fragment = Nokogiri::HTML5.fragment(html)
    if para = fragment.css("p:first").first
      para["style"] = "margin-top: #{desired};"
    end
    fragment.to_html.html_safe
  end

  def logo_url
    logo_url = SiteSetting.site_digest_logo_url
    logo_url = SiteSetting.site_logo_url if logo_url.blank? || logo_url =~ /\.svg\z/i
    return nil if logo_url.blank? || logo_url =~ /\.svg\z/i
    logo_url
  end

  def html_site_link
    "<a href='#{Discourse.base_url}'>#{@site_name}</a>"
  end

  def first_paragraphs_from(html)
    doc = Nokogiri.HTML5(html)

    result = +""
    length = 0

    doc
      .css("body > p, aside.onebox, body > ul, body > blockquote")
      .each do |node|
        if node.text.present?
          result << node.to_s
          length += node.inner_text.length
          return result if length >= SiteSetting.digest_min_excerpt_length
        end
      end

    return result if result.present?

    # If there is no first paragraph with text, return the first paragraph with
    # something else (an image) or div (a onebox).
    doc.css(
      "body > p:not(:empty), body > div:not(:empty), body > p > div.lightbox-wrapper img",
    ).first
  end

  def email_excerpt(html_arg, post = nil)
    html = (first_paragraphs_from(html_arg) || html_arg).to_s
    PrettyText.format_for_email(html, post).html_safe
  end

  def normalize_name(name)
    name.downcase.gsub(/[\s_-]/, "")
  end

  def show_username_on_post(post)
    return true unless SiteSetting.enable_names?
    return true unless SiteSetting.display_name_on_posts?
    return true if post.user.name.blank?

    normalize_name(post.user.name) != normalize_name(post.user.username)
  end

  def show_name_on_post(post)
    SiteSetting.enable_names? && SiteSetting.display_name_on_posts? && post.user.name.present? &&
      normalize_name(post.user.name) != normalize_name(post.user.username)
  end

  def format_for_email(post, use_excerpt)
    html = use_excerpt ? post.excerpt : post.cooked
    PrettyText.format_for_email(html, post).html_safe
  end

  def digest_custom_html(position_key)
    digest_custom "user_notifications.digest.custom.html.#{position_key}"
  end

  def digest_custom_text(position_key)
    digest_custom "user_notifications.digest.custom.text.#{position_key}"
  end

  def digest_custom(i18n_key)
    PrettyText.format_for_email(I18n.t(i18n_key)).html_safe
  end

  def show_image_with_url(url)
    !(url.nil? || url.downcase.end_with?("svg"))
  end

  def email_image_url(basename)
    UrlHelper.absolute("#{Discourse.base_path}/images/emails/#{basename}")
  end

  def url_for_email(href)
    URI(href).host.present? ? href : UrlHelper.absolute("#{Discourse.base_path}#{href}")
  rescue URI::Error
    href
  end

  def render_digest_header
    if I18n.t("user_notifications.digest.custom.html.header").present?
      return render("user_notifications/digest/custom_header")
    end

    render("user_notifications/digest/header")
  end
end
