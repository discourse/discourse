# frozen_string_literal: true

require_dependency "pretty_text"

class InlineUploads
  PLACEHOLDER = "__replace__"
  PATH_PLACEHOLDER = "__replace_path__"

  UPLOAD_REGEXP_PATTERN = "/original/(\\dX/(?:[a-f0-9]/)*[a-f0-9]{40}[a-zA-Z0-9.]*)"
  private_constant :UPLOAD_REGEXP_PATTERN

  def self.process(markdown, on_missing: nil)
    markdown = markdown.dup

    match_md_reference(markdown) do |match, src, replacement, index|
      if upload = Upload.get_from_url(src)
        markdown = markdown.sub(match, replacement.sub!(PATH_PLACEHOLDER, "__#{upload.sha1}__"))
      end
    end

    cooked_fragment = Nokogiri::HTML::fragment(PrettyText.cook(markdown, disable_emojis: true))
    link_occurences = []

    cooked_fragment.traverse do |node|
      if node.name == "img"
        # Do nothing
      elsif !(node.children.count == 1 && (node.children[0].name != "img" && node.children[0].children.blank?)) &&
        !(node.name == "a" && node.children.count > 1 && !node_children_names(node).include?("img"))

        next
      end

      if seen_link = matched_uploads(node).first
        if (actual_link = (node.attributes["href"]&.value || node.attributes["src"]&.value))
          link_occurences << { link: actual_link, is_valid: true }
        elsif node.name != "p"
          link_occurences << { link: actual_link, is_valid: false }
        end
      end
    end

    raw_matches = []

    match_bbcode_img(markdown) do |match, src, replacement, index|
      raw_matches << [match, src, replacement, index]
    end

    match_md_inline_img(markdown) do |match, src, replacement, index|
      raw_matches << [match, src, replacement, index]
    end

    match_img(markdown) do |match, src, replacement, index|
      raw_matches << [match, src, replacement, index]
    end

    match_anchor(markdown) do |match, href, replacement, index|
      raw_matches << [match, href, replacement, index]
    end

    db = RailsMultisite::ConnectionManagement.current_db

    regexps = [
      /(https?:\/\/[a-zA-Z0-9\.\/-]+\/uploads\/#{db}#{UPLOAD_REGEXP_PATTERN})/,
    ]

    if Discourse.store.external?
      regexps << /((https?:)?#{SiteSetting.Upload.s3_base_url}#{UPLOAD_REGEXP_PATTERN})/
      regexps << /(#{SiteSetting.Upload.s3_cdn_url}#{UPLOAD_REGEXP_PATTERN})/
    end

    regexps.each do |regexp|
      indexes = Set.new

      markdown.scan(/(\n{2,}|\A)#{regexp}$/) do |match|
        if match[1].present?
          extension = match[1].split(".")[-1].downcase
          index = $~.offset(2)[0]
          indexes << index
          if FileHelper.supported_images.include?(extension)
            raw_matches << [match[1], match[1], +"![](#{PLACEHOLDER})", index]
          else
            raw_matches << [match[1], match[1], +"#{Discourse.base_url}#{PATH_PLACEHOLDER}", index]
          end
        end
      end

      markdown.scan(/^#{regexp}(\s)/) do |match|
        if match[0].present?
          index = $~.offset(0)[0]
          next if indexes.include?(index)
          indexes << index

          raw_matches << [
            match[0],
            match[0],
            +"#{Discourse.base_url}#{PATH_PLACEHOLDER}",
            $~.offset(0)[0]
          ]
        end
      end

      markdown.scan(/\[[^\[\]]*\]: #{regexp}/) do |match|
        if match[0].present?
          index = $~.offset(1)[0]
          next if indexes.include?(index)
          indexes << index
        end
      end

      markdown.scan(/(([\n\s\)\]\<])+)#{regexp}/) do |match|
        if matched_uploads(match[2]).present?
          next if indexes.include?($~.offset(3)[0])

          raw_matches << [
            match[2],
            match[2],
            +"#{Discourse.base_url}#{PATH_PLACEHOLDER}",
            $~.offset(0)[0]
          ]
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
          host = uri&.host

          hosts = [Discourse.current_hostname]

          if cdn_url = GlobalSetting.cdn_url
            hosts << URI(GlobalSetting.cdn_url).hostname
          end

          if host && !hosts.include?(host)
            next
          end
        end

        upload = Upload.get_from_url(link)

        if upload
          replace_with.sub!(PLACEHOLDER, upload.short_url)
          replace_with.sub!(PATH_PLACEHOLDER, upload.short_path)
          markdown.sub!(match, replace_with)
        else
          on_missing.call(link) if on_missing
        end
      end
    end

    markdown.scan(/(__([a-f0-9]{40})__)/) do |match|
      upload = Upload.find_by(sha1: match[1])
      markdown = markdown.sub(match[0], upload.short_path)
    end

    markdown
  end

  def self.match_md_inline_img(markdown, external_src: false)
    markdown.scan(/(!?\[([^\[\]]*)\]\(([a-zA-z0-9\.\/:-]+)([ ]*['"]{1}[^\)]*['"]{1}[ ]*)?\))/) do |match|
      if (matched_uploads(match[2]).present? || external_src) && block_given?
        yield(
          match[0],
          match[2],
          +"#{match[0].start_with?("!") ? "!" : ""}[#{match[1]}](#{PLACEHOLDER}#{match[3]})",
          $~.offset(0)[0]
        )
      end
    end
  end

  def self.match_bbcode_img(markdown, external_src: false)
    markdown.scan(/(\[img\]\s*([^\[\]\s]+)\s*\[\/img\])/) do |match|
      if (matched_uploads(match[1]).present? && block_given?) || external_src
        yield(match[0], match[1], +"![](#{PLACEHOLDER})", $~.offset(0)[0])
      end
    end
  end

  def self.match_md_reference(markdown)
    markdown.scan(/(\[([^\]]+)\]:([ ]+)(\S+))/) do |match|
      if match[3] && matched_uploads(match[3]).present? && block_given?
        yield(
          match[0],
          match[3],
          +"[#{match[1]}]:#{match[2]}#{Discourse.base_url}#{PATH_PLACEHOLDER}",
          $~.offset(0)[0]
        )
      end
    end
  end

  def self.match_anchor(markdown, external_href: false)
    markdown.scan(/((<a[^<]+>)([^<\a>]*?)<\/a>)/) do |match|
      node = Nokogiri::HTML::fragment(match[0]).children[0]
      href =  node.attributes["href"]&.value

      if href && (matched_uploads(href).present? || external_href)
        has_attachment = node.attributes["class"]&.value
        index = $~.offset(0)[0]
        text = match[2].strip.gsub("\n", "").gsub(/ +/, " ")
        text = "#{text}|attachment" if has_attachment

        yield(match[0], href, +"[#{text}](#{PLACEHOLDER})", index) if block_given?
      end
    end
  end

  def self.match_img(markdown, external_src: false)
    markdown.scan(/(([ ]*)<(?!img)[^<>]+\/?>)?([\r\n]*)(([ ]*)<img ([^>\n]+)>([ ]*))([\r\n]*)/) do |match|
      node = Nokogiri::HTML::fragment(match[3].strip).children[0]
      src =  node.attributes["src"]&.value

      if src && (matched_uploads(src).present? || external_src)
        text = node.attributes["alt"]&.value
        width = node.attributes["width"]&.value.to_i
        height = node.attributes["height"]&.value.to_i
        title = node.attributes["title"]&.value
        text = "#{text}|#{width}x#{height}" if width > 0 && height > 0
        after_html_tag = match[0].present?

        spaces_before =
          if after_html_tag && !match[0].end_with?("/>")
            (match[4].length > 0 ? match[4] : "  ")
          else
            ""
          end

        replacement = +"#{spaces_before}![#{text}](#{PLACEHOLDER}#{title.present? ? " \"#{title}\"" : ""})"

        if after_html_tag && (num_newlines = match[2].length) <= 1
          replacement.prepend("\n" * (num_newlines == 0 ? 2 : 1))
        end

        if after_html_tag && !match[0].end_with?("/>") && (num_newlines = match[7].length) <= 1
          replacement += ("\n" * (num_newlines == 0 ? 2 : 1))
        end

        match[3].strip! if !after_html_tag

        if (match[1].nil? || match[1].length < 4)
          if (match[4].nil? || match[4].length < 4)
            yield(match[3], src, replacement, $~.offset(0)[0]) if block_given?
          else
            yield(match[3], src, match[3].sub(src, PATH_PLACEHOLDER), $~.offset(0)[0]) if block_given?
          end
        else
          yield(match[3], src, match[3].sub(src, PATH_PLACEHOLDER), $~.offset(0)[0]) if block_given?
        end
      end
    end
  end

  def self.matched_uploads(node)
    matches = []

    base_url = Discourse.base_url.sub(/https?:\/\//, "(https?://)")

    if GlobalSetting.cdn_url
      cdn_url = GlobalSetting.cdn_url.sub(/https?:\/\//, "(https?://)")
    end

    db = RailsMultisite::ConnectionManagement.current_db

    regexps = [
      /(upload:\/\/([a-zA-Z0-9]+)[a-zA-Z0-9\.]*)/,
      /(\/uploads\/short-url\/([a-zA-Z0-9]+)[a-zA-Z0-9\.]*)/,
      /(#{base_url}\/uploads\/short-url\/([a-zA-Z0-9]+)[a-zA-Z0-9\.]*)/,
      /(#{GlobalSetting.relative_url_root}\/uploads\/#{db}#{UPLOAD_REGEXP_PATTERN})/,
      /(#{base_url}\/uploads\/#{db}#{UPLOAD_REGEXP_PATTERN})/,
    ]

    regexps << /(#{cdn_url}\/uploads\/#{db}#{UPLOAD_REGEXP_PATTERN})/ if cdn_url

    if Discourse.store.external?
      if Rails.configuration.multisite
        regexps << /((https?:)?#{SiteSetting.Upload.s3_base_url}\/uploads\/#{db}#{UPLOAD_REGEXP_PATTERN})/
        regexps << /(#{SiteSetting.Upload.s3_cdn_url}\/uploads\/#{db}#{UPLOAD_REGEXP_PATTERN})/
      else
        regexps << /((https?:)?#{SiteSetting.Upload.s3_base_url}#{UPLOAD_REGEXP_PATTERN})/
        regexps << /(#{SiteSetting.Upload.s3_cdn_url}#{UPLOAD_REGEXP_PATTERN})/
      end
    end

    node = node.to_s

    regexps.each do |regexp|
      node.scan(/(^|[\n\s"'\(>])#{regexp}($|[\n\s"'\)<])/) do |matched|
        matches << matched[1]
      end
    end

    matches
  end
  private_class_method :matched_uploads

  def self.node_children_names(node, names = Set.new)
    if node.children.blank?
      names << node.name
      return names
    end

    node.children.each do |child|
      names = node_children_names(child, names)
    end

    names
  end
  private_class_method :node_children_names
end
