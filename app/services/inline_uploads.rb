# frozen_string_literal: true

require_dependency "pretty_text"

class InlineUploads
  PLACEHOLDER = "__replace__"
  private_constant :PLACEHOLDER

  UPLOAD_REGEXP_PATTERN = "/original/(\\dX/(?:[a-f0-9]/)*[a-f0-9]{40}[a-z0-9.]*)"
  private_constant :UPLOAD_REGEXP_PATTERN

  def self.process(markdown, on_missing: nil)
    markdown = markdown.dup
    cooked_fragment = Nokogiri::HTML::fragment(PrettyText.cook(markdown, disable_emojis: true))
    link_occurences = []

    cooked_fragment.traverse do |node|
      if node.name == "img"
        # Do nothing
      elsif !(node.children.count == 1 && (node.children[0].name != "img" && node.children[0].children.blank?)) ||
            !node.ancestors.all? { |parent| !parent.attributes["class"]&.value&.include?("quote") }
        next
      end

      if seen_link = matched_uploads(node).first
        link_occurences <<
          if (actual_link = (node.attributes["href"]&.value || node.attributes["src"]&.value))
            { link: actual_link, is_valid: true }
          else
            { link: seen_link, is_valid: false }
          end
      end
    end

    raw_matches = []

    markdown.scan(/(\[img\]\s?(.+)\s?\[\/img\])/) do |match|
      raw_matches << [match[0], match[1], +"![](#{PLACEHOLDER})", $~.offset(0)[0]]
    end

    markdown.scan(/(!?\[([^\[\]]+)\]\(([a-zA-z0-9\.\/:-]+)\))/) do |match|
      if matched_uploads(match[2]).present?
        raw_matches << [
          match[0],
          match[2],
          +"#{match[0].start_with?("!") ? "!" : ""}[#{match[1]}](#{PLACEHOLDER})",
          $~.offset(0)[0]
        ]
      end
    end

    markdown.scan(/(<(?!img)[^<>]+\/?>)?(\n*)(([ ]*)<img ([^<>]+)>([ ]*))(\n*)/) do |match|
      node = Nokogiri::HTML::fragment(match[2].strip).children[0]
      src =  node.attributes["src"].value

      if matched_uploads(src).present?
        text = node.attributes["alt"]&.value
        width = node.attributes["width"]&.value
        height = node.attributes["height"]&.value
        text = "#{text}|#{width}x#{height}" if width && height
        after_html_tag = match[0].present?

        spaces_before =
          if after_html_tag && !match[0].end_with?("/>")
            (match[3].present? ? match[3] : "  ")
          else
            ""
          end

        replacement = +"#{spaces_before}![#{text}](#{PLACEHOLDER})"

        if after_html_tag && (num_newlines = match[1].length) <= 1
          replacement.prepend("\n" * (num_newlines == 0 ? 2 : 1))
        end

        if after_html_tag && !match[0].end_with?("/>") && (num_newlines = match[6].length) <= 1
          replacement += ("\n" * (num_newlines == 0 ? 2 : 1))
        end

        match[2].strip! if !after_html_tag

        raw_matches << [
          match[2],
          src,
          replacement,
          $~.offset(0)[0]
        ]
      end
    end

    markdown.scan(/((<a[^<]+>)([^<\a>]*?)<\/a>)/) do |match|
      node = Nokogiri::HTML::fragment(match[0]).children[0]
      href =  node.attributes["href"]&.value

      if href && matched_uploads(href).present?
        has_attachment = node.attributes["class"]&.value
        index = $~.offset(0)[0]
        text = match[2].strip.gsub("\n", "").gsub(/ +/, " ")
        text = "#{text}|attachment" if has_attachment
        raw_matches << [match[0], href, +"[#{text}](#{PLACEHOLDER})", index]
      end
    end

    db = RailsMultisite::ConnectionManagement.current_db

    regexps = [
      /(^|\s)?(https?:\/\/[a-zA-Z0-9\.\/-]+\/uploads\/#{db}#{UPLOAD_REGEXP_PATTERN})($|\s)/,
    ]

    if Discourse.store.external?
      regexps << /(^|\s)?(https?:#{SiteSetting.Upload.s3_base_url}#{UPLOAD_REGEXP_PATTERN})($|\s)?/
      regexps << /(^|\s)?(#{SiteSetting.Upload.s3_cdn_url}#{UPLOAD_REGEXP_PATTERN})($|\s)?/
    end

    regexps.each do |regexp|
      markdown.scan(regexp) do |match|
        if matched_uploads(match[1]).present?
          raw_matches << [match[1], match[1], +"![](#{PLACEHOLDER})", $~.offset(0)[0]]
        end
      end
    end

    raw_matches
      .sort { |a, b| a[3] <=> b[3] }
      .each do |match, link, replace_with, _index|

      node_info = link_occurences.shift
      next unless node_info&.dig(:is_valid)

      if link.include?(node_info[:link])
        begin
          uri = URI(link)
        rescue URI::Error
        end

        if !Discourse.store.external?
          next if uri&.host && uri.host != Discourse.current_hostname
        end

        upload = Upload.get_from_url(link)

        if upload
          replacement = replace_with.sub!(PLACEHOLDER, upload.short_url)
          markdown.sub!(match, replacement)
        else
          on_missing.call(link) if on_missing
        end
      end
    end

    markdown
  end

  def self.matched_uploads(node)
    matches = []

    regexps = [
      /(upload:\/\/([a-zA-Z0-9]+)[a-z0-9\.]*)/,
      /(\/uploads\/short-url\/([a-zA-Z0-9]+)[a-z0-9\.]*)/,
    ]

    db = RailsMultisite::ConnectionManagement.current_db

    if Discourse.store.external?
      if Rails.configuration.multisite
        regexps << /(#{SiteSetting.Upload.s3_base_url}\/uploads\/#{db}#{UPLOAD_REGEXP_PATTERN})/
        regexps << /(#{SiteSetting.Upload.s3_cdn_url}\/uploads\/#{db}#{UPLOAD_REGEXP_PATTERN})/
      else
        regexps << /(#{SiteSetting.Upload.s3_base_url}#{UPLOAD_REGEXP_PATTERN})/
        regexps << /(#{SiteSetting.Upload.s3_cdn_url}#{UPLOAD_REGEXP_PATTERN})/
        regexps << /(\/uploads\/#{db}#{UPLOAD_REGEXP_PATTERN})/
      end
    else
      regexps << /(\/uploads\/#{db}#{UPLOAD_REGEXP_PATTERN})/
    end

    node = node.to_s

    regexps.each do |regexp|
      node.scan(regexp) do |matched|
        matches << matched[0]
      end
    end

    matches
  end
  private_class_method :matched_uploads
end
