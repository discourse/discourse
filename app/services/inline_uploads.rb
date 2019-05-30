# frozen_string_literal: true

require_dependency "pretty_text"

class InlineUploads
  def self.process(markdown)
    cooked_fragment = Nokogiri::HTML::fragment(PrettyText.cook(markdown.dup))
    link_occurences = []

    cooked_fragment.traverse do |node|
      next unless node.children.count == 1 && node.children[0].children.blank?

      if seen_link = upload_fragment_hint(node)
        if actual_link = node.attributes["href"]&.value
          link_occurences << [actual_link, true]
        else
          link_occurences << [seen_link, false]
        end
      end
    end

    raw_fragment = Nokogiri::HTML::fragment(markdown)

    raw_fragment.children.each do |fragment|
      if upload_fragment_hint(fragment)
        seen_link, is_valid = link_occurences.shift
        link = fragment.attributes["href"]&.value

        next unless (link && is_valid)

        if link.include?(seen_link)
          begin
            uri = URI(link)
          rescue URI::Error
          end

          next if uri.host && uri.host != Discourse.current_hostname

          upload = Upload.get_from_url(link)

          if upload
            attachment_postfix =
              if fragment.attributes["class"]&.value&.split(" ")&.include?("attachment")
                "|attachment"
              else
                ""
              end

            text = fragment.children.text.strip.gsub("\n", "").gsub(/ +/, " ")

            fragment.replace("[#{text}#{attachment_postfix}](#{upload.short_url})")
          end
        end
      end
    end

    raw_fragment.to_s
  end

  def self.upload_fragment_hint(fragment)
    if fragment.to_s =~ /\/uploads\/default\/original\/(\dX\/(?:[a-f0-9]\/)*[a-f0-9]{40}[a-z0-9\.]*)/ ||
       fragment.to_s =~ /upload:\/\/([a-zA-Z0-9]+)(\..*)/

      Regexp.last_match[0]
    end
  end
end
