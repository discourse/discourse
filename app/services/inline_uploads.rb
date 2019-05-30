# frozen_string_literal: true

require_dependency "pretty_text"

class InlineUploads
  def self.process(markdown, on_missing: nil)
    markdown = markdown.dup
    cooked_fragment = Nokogiri::HTML::fragment(PrettyText.cook(markdown))
    link_occurences = []

    cooked_fragment.traverse do |node|
      if node.name == "img"
        # Do nothing
      elsif !(node.children.count == 1 && (node.children[0].name != "img" && node.children[0].children.blank?))
        next
      end

      if seen_link = matched_uploads(node).first
        if actual_link = (node.attributes["href"]&.value || node.attributes["src"]&.value)
          link_occurences << [actual_link, true]
        else
          link_occurences << [seen_link, false]
        end
      end
    end

    raw_fragment = Nokogiri::HTML::fragment(markdown)

    raw_fragment.traverse do |node|
      if node.name == "img"
        # Do nothing
      elsif !(node.children.count == 0 || (node.children.count == 1 && node.children[0].children.blank?))
        next
      end

      matches = matched_uploads(node)
      next if matches.blank?
      links = extract_links(node)

      matches.zip(links).each do |_match, link|
        seen_link, is_valid = link_occurences.shift
        next unless (link && is_valid)

        if link.include?(seen_link)
          begin
            uri = URI(link)
          rescue URI::Error
          end

          if !Discourse.store.external?
            next if uri&.host && uri.host != Discourse.current_hostname
          end

          upload = Upload.get_from_url(link)

          if upload
            new_node =
              case node.name
              when 'a'
                attachment_postfix =
                  if node.attributes["class"]&.value&.split(" ")&.include?("attachment")
                    "|attachment"
                  else
                    ""
                  end

                text = node.children.text.strip.gsub("\n", "").gsub(/ +/, " ")

                markdown.sub!(
                  node.to_s,
                  "[#{text}#{attachment_postfix}](#{upload.short_url})"
                )
              when "img"
                text = node.attributes["alt"]&.value
                width = node.attributes["width"]&.value
                height = node.attributes["height"]&.value
                text = "#{text}|#{width}x#{height}" if width && height
                markdown.sub!(node.to_s, "![#{text}](#{upload.short_url})")
              else
                if markdown =~ /\[img\]\s?#{link}\s?\[\/img\]/
                  capture = Regexp.last_match[0]

                  if capture
                    markdown.sub!(capture, "![](#{upload.short_url})")
                  end
                elsif markdown =~ /(!?\[([a-z0-9|]+)\]\([a-zA-z0-9\.\/]+\))/
                  capture = Regexp.last_match[0]

                  if capture
                    markdown.sub!(capture, "![#{Regexp.last_match[2]}](#{upload.short_url})")
                  end
                end
              end

          else
            on_missing.call(link) if on_missing
          end
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
        regexps << /(#{SiteSetting.Upload.s3_base_url}\/uploads\/#{db}\/original\/(\dX\/(?:[a-f0-9]\/)*[a-f0-9]{40}[a-z0-9\.]*))/
        regexps << /(#{SiteSetting.Upload.s3_cdn_url}\/uploads\/#{db}\/original\/(\dX\/(?:[a-f0-9]\/)*[a-f0-9]{40}[a-z0-9\.]*))/
      else
        regexps << /(#{SiteSetting.Upload.s3_base_url}\/original\/(\dX\/(?:[a-f0-9]\/)*[a-f0-9]{40}[a-z0-9\.]*))/
        regexps << /(#{SiteSetting.Upload.s3_cdn_url}\/original\/(\dX\/(?:[a-f0-9]\/)*[a-f0-9]{40}[a-z0-9\.]*))/
        regexps << /(\/uploads\/#{db}\/original\/(\dX\/(?:[a-f0-9]\/)*[a-f0-9]{40}[a-z0-9\.]*))/
      end
    else
      regexps << /(\/uploads\/#{db}\/original\/(\dX\/(?:[a-f0-9]\/)*[a-f0-9]{40}[a-z0-9\.]*))/
    end

    node = node.to_s

    regexps.each do |regexp|
      node.scan(regexp).each do |matched|
        matches << matched[0]
      end
    end

    matches
  end
  private_class_method :matched_uploads

  def self.extract_links(node)
    links = []
    links << node.attributes["href"]&.value
    links << node.attributes["src"]&.value
    links = links.concat(node.to_s.scan(/\[img\]\s?(.+)\s?\[\/img\]/))
    links = links.concat(node.to_s.scan(/!?\[[a-z0-9|]+\]\(([a-zA-z0-9\.\/]+)\)/))
    links.flatten!
    links.compact!
    links
  end
  private_class_method :extract_links
end
