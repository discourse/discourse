# frozen_string_literal: true

class QuoteRewriter
  # Keep in sync with QUOTATION_MARKS in bbcode-block.js
  QUOTATION_MARKS = /["'«»“”‘’„‚‹›]/

  def initialize(user_id)
    @user_id = user_id
  end

  def rewrite_raw_username(raw, old_username, new_username)
    escaped_old_username = Regexp.escape(old_username)
    pattern =
      Regexp.union(
        /(?<pre>\[quote\s*=\s*["'']?.*username:)#{escaped_old_username}(?<post>\,?[^\]]*\])/i,
        /(?<pre>\[quote\s*=\s*["'']?)#{escaped_old_username}(?<post>\,?[^\]]*\])/i,
      )

    raw.gsub(pattern, "\\k<pre>#{new_username}\\k<post>")
  end

  def rewrite_cooked_username(cooked, old_username, new_username, avatar_img)
    formatted_old_username = PrettyText::Helpers.format_username(old_username)
    escaped_old_username = Regexp.escape(formatted_old_username)
    pattern = /(?<=\s)#{escaped_old_username}(?=:)/i

    cooked
      .css("aside.quote")
      .each do |aside|
        next unless div = aside.at_css("div.title")

        username_replaced = false

        aside["data-username"] = new_username if aside["data-username"] == old_username

        div.children.each do |child|
          if child.text?
            content = child.content
            username_replaced = content.gsub!(pattern, new_username).present?
            child.content = content if username_replaced
          end
        end

        if username_replaced || quotes_correct_user?(aside)
          div.at_css("img.avatar")&.replace(avatar_img)
        end
      end
  end

  def rewrite_display_name(raw:, cooked:, old_display_name:, new_display_name:, username:)
    hide_display_name = !SiteSetting.enable_names?
    display_name = hide_display_name ? username : new_display_name
    username_to_remove = username if hide_display_name
    rewritten_raw =
      rewrite_raw_display_name(
        raw,
        old_display_name,
        display_name,
        username_to_remove: username_to_remove,
      )

    return { raw: raw, cooked: cooked } if rewritten_raw == raw
    return { raw: rewritten_raw, cooked: cooked } if cooked.nil?

    doc = Nokogiri::HTML5.fragment(cooked)
    rewrite_cooked_display_name(
      doc,
      old_display_name,
      display_name,
      hide_display_name: hide_display_name,
    )

    { raw: rewritten_raw, cooked: doc.to_html }
  end

  def rewrite_raw_display_name(raw, old_display_name, new_display_name, username_to_remove: nil)
    old_display_names = quoted_display_names(old_display_name)
    return raw if old_display_names.empty?

    new_display_name = quotable_display_name(new_display_name)
    pattern =
      /
      (?<pre>
        ^(?:[\t\x20>]|[*+\-][\t\x20]|\d+[.)][\t\x20])*
        \[quote=(?<mark>["']?)
      )
      (?<name>#{Regexp.union(old_display_names).source})
      (?<post>,[^\]\r\n]*username[^\]\r\n]*\])
    /ix

    raw.gsub(pattern) do |quote|
      match = Regexp.last_match
      mark = match[:mark]
      next quote if match[:name].include?(mark.presence || "]")
      next quote if mark.empty? && match[:name].start_with?(QUOTATION_MARKS)
      next quote if !match[:post].end_with?("#{mark}]")

      pre = match[:pre]
      post = match[:post]

      if username_to_remove
        username_attribute = /,\s*username:\s*#{Regexp.escape(username_to_remove)}(?=\s*[,"'\]])/i
        rewritten_post = post.sub(username_attribute, "")
        next quote if rewritten_post == post

        post = rewritten_post
      end

      display_name = mark.empty? ? new_display_name.delete("]") : new_display_name

      "#{pre}#{display_name}#{post}"
    end
  end

  def rewrite_cooked_display_name(
    cooked,
    old_display_name,
    new_display_name,
    hide_display_name: false
  )
    formatted_old_display_name = PrettyText::Helpers.format_username(old_display_name)
    escaped_old_display_name = Regexp.escape(formatted_old_display_name)
    pattern = /(?<=\s)#{escaped_old_display_name}(?=:)/i

    cooked
      .css("aside.quote")
      .each do |aside|
        next unless div = aside.at_css("div.title")

        if hide_display_name && aside["data-display-name"] == old_display_name
          aside.remove_attribute("data-display-name")
        elsif aside["data-display-name"] == old_display_name
          aside["data-display-name"] = new_display_name
        end

        div.children.each do |child|
          if child.text?
            content = child.content
            display_name_replaced = content.gsub!(pattern, new_display_name).present?
            child.content = content if display_name_replaced
          end
        end
      end
  end

  private

  attr_reader :user_id

  def quotable_display_name(display_name)
    display_name.gsub(QUOTATION_MARKS, "").squish
  end

  def quoted_display_names(display_name)
    [display_name, quotable_display_name(display_name)].uniq.reject do
      it.blank? || it.match?(/[\r\n]/)
    end
  end

  def quotes_correct_user?(aside)
    Post.exists?(topic_id: aside["data-topic"], post_number: aside["data-post"], user_id: user_id)
  end
end
