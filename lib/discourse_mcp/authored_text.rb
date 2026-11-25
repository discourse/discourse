# frozen_string_literal: true

module DiscourseMcp
  # Checks text that an agent writes through MCP while a content rule is
  # active.
  #
  # Agent text may not reference anything on the site: no internal or
  # upload-host URLs, no quotes that name a topic or post, no hashtags, and no
  # link that the platform could later expand into a onebox, whatever its host.
  # External links are allowed only as labelled links, and media only as
  # uploads granted to the caller's authorization. Every rejected form gets the
  # same error, and nothing is resolved while checking, so the answer never
  # depends on whether a referenced record exists or is restricted.
  #
  # The check renders the text with the markdown pipeline but stops before
  # enrichment, so it never fetches or expands anything. Bare URLs are found
  # in the rendered text as well as in links, so the result doesn't depend on
  # the linkify and onebox settings, which could change before a later rebake.
  class AuthoredText
    # The arguments of each tool that hold text an agent writes and the site
    # later renders or displays. `*` matches every value of a hash argument.
    AUTHORED_ARGUMENTS = {
      "discourse_create_topic" => %w[title raw],
      "discourse_create_post" => %w[raw],
      "discourse_update_post" => %w[raw edit_reason],
      "discourse_update_topic" => %w[title featured_link],
      "discourse_create_private_message" => %w[title raw],
      "discourse_reply_private_message" => %w[raw],
      "discourse_invite_to_private_message" => %w[custom_message],
      "discourse_create_category" => %w[name description],
      "discourse_update_category" => %w[name description],
      "discourse_create_group" => %w[full_name title bio_raw membership_request_template],
      "discourse_update_group" => %w[full_name title bio_raw membership_request_template],
      "discourse_manage_group_membership" => %w[reason],
      "discourse_update_user" => %w[name title bio_raw location website],
      "discourse_create_user" => %w[name user_fields.*],
      "discourse_suspend_user" => %w[reason message],
      "discourse_silence_user" => %w[reason message],
      "discourse_save_draft" => %w[title reply],
      "discourse_user_status_set" => %w[description],
    }.freeze

    MEDIA_ELEMENTS = %w[img video audio source track picture embed object iframe].freeze
    MEDIA_ATTRIBUTES = %w[src srcset poster data data-src data-orig-src data-orig-srcset].freeze
    CODE_ANCESTORS = %w[code pre].freeze
    ONEBOX_CLASSES = %w[onebox inline-onebox inline-onebox-loading].freeze

    SCHEME_URL = %r{(?<![\p{L}\p{N}])[a-z][a-z0-9+.\-]*://\S+}i
    WWW_URL = /(?<![\p{L}\p{N}.\-@])www\.\S+/i
    DOMAIN =
      /(?<![\p{L}\p{N}.\-@])((?:[\p{L}\p{N}](?:[\p{L}\p{N}\-]*[\p{L}\p{N}])?\.)+\p{L}{2,})(?![\p{L}\p{N}\-])/
    HASHTAG = /(?<![\p{L}\p{N}&\/])#[\p{L}\p{N}][\p{L}\p{N}_:\-]*/

    # @param tool_identifier [String]
    # @param arguments [Hash] The tool's arguments.
    # @returns [Array<String>] The authored values the tool received.
    def self.values_for(tool_identifier, arguments)
      AUTHORED_ARGUMENTS
        .fetch(tool_identifier, [])
        .flat_map do |path|
          name, nested = path.split(".", 2)
          value = arguments[name]
          value = value.is_a?(Hash) ? value.values : [] if nested == "*"
          Array(value).flatten
        end
        .select { |value| value.is_a?(String) && value.present? }
    end

    # @param request_context [RequestContext]
    def initialize(request_context)
      @request_context = request_context
      @granted_upload_ids = Set.new
    end

    # The granted uploads the checked texts referenced, so the records this
    # call writes with them can be recorded afterwards.
    #
    # @returns [Set<Integer>]
    attr_reader :granted_upload_ids

    # Raises the policy error when any of the texts holds a reference.
    #
    # @param texts [Array<String>]
    # @returns [void]
    def ensure_allowed!(*texts)
      texts.each { |text| raise_blocked! if !allowed?(text) }
    end

    # @param text [String]
    # @returns [Boolean]
    def allowed?(text)
      return true if text.blank?

      fragment = Nokogiri::HTML5.fragment(PrettyText.cook(text.to_s, onebox_limit: "none"))
      allowed_elements?(fragment) && allowed_text?(fragment)
    end

    # Raises the policy error unless the upload is granted to the caller.
    #
    # @param upload [Upload, nil]
    # @returns [void]
    def ensure_granted_upload!(upload)
      raise_blocked! if !use_upload(upload)
    end

    private

    def raise_blocked!
      raise ToolError, I18n.t("mcp.errors.content_policy_blocked")
    end

    def allowed_elements?(fragment)
      return false if fragment.at_css("[data-onebox-src], [data-download-href], .hashtag-cooked")
      if fragment.at_css(".hashtag-raw, aside.quote[data-topic], aside.quote[data-post]")
        return false
      end

      fragment.css("a").all? { |anchor| allowed_anchor?(anchor) } &&
        fragment.css(MEDIA_ELEMENTS.join(", ")).all? { |element| allowed_media?(element) }
    end

    def allowed_anchor?(anchor)
      classes = anchor.classes
      return false if classes.intersect?(ONEBOX_CLASSES)
      if classes.intersect?(%w[mention mention-group])
        return anchor.text.start_with?("@") && anchor.css("img").empty?
      end
      href = anchor["href"].to_s.strip
      upload = upload_for(anchor["data-orig-href"].presence || href)
      return use_upload(upload) if upload
      return false if anchor["data-orig-href"].present?

      return true if href.start_with?("#")
      return true if href.downcase.start_with?("mailto:")
      return false if !external_url?(href)

      !url_like?(anchor.text)
    end

    def allowed_media?(element)
      if element.name == "img" && element.classes.include?("emoji")
        return emoji_url?(element["src"])
      end

      MEDIA_ATTRIBUTES.all? do |attribute|
        value = element[attribute]
        next true if value.blank?
        # A placeholder replaces the source of an image that references an
        # upload, which `data-orig-src` then carries.
        next true if attribute == "src" && element["data-orig-src"].present?

        candidates = attribute.end_with?("srcset") ? srcset_urls(value) : [value]
        candidates.all? { |url| granted?(url) }
      end
    end

    def allowed_text?(fragment)
      fragment
        .xpath(".//text()")
        .reject { |node| node.ancestors.any? { |ancestor| CODE_ANCESTORS.include?(ancestor.name) } }
        .none? { |node| url_like?(node.text) || node.text.match?(HASHTAG) }
    end

    def url_like?(text)
      return true if text.match?(SCHEME_URL) || text.match?(WWW_URL)

      text.scan(DOMAIN).any? { |(domain)| PublicSuffix.valid?(domain.downcase, default_rule: nil) }
    end

    def srcset_urls(value)
      value.split(",").filter_map { |candidate| candidate.strip.split(/\s+/).first.presence }
    end

    def emoji_url?(src)
      return false if src.blank?

      path = URI.parse(src).path.to_s
      path.start_with?("#{Discourse.base_path}/images/emoji/") && !internal_host?(URI.parse(src))
    rescue URI::Error
      false
    end

    def external_url?(href)
      uri = URI.parse(href)
      %w[http https].include?(uri.scheme&.downcase) && uri.host.present? && !internal_host?(uri)
    rescue URI::Error
      false
    end

    def internal_host?(uri)
      uri.host.present? && internal_hosts.include?(uri.host.downcase)
    end

    def internal_hosts
      @internal_hosts ||=
        [
          Discourse.current_hostname,
          Discourse.base_url,
          GlobalSetting.cdn_url,
          SiteSetting.s3_cdn_url,
          (Discourse.store.absolute_base_url if Discourse.store.external?),
        ].compact_blank
          .filter_map do |value|
            value.include?("://") ? URI.parse(value).host : value
          rescue URI::Error
            nil
          end
          .map(&:downcase)
          .to_set
    end

    # Only an upload this authorization created through MCP, and that no
    # record outside the ones it wrote references, may be used.
    def granted?(url)
      use_upload(upload_for(url))
    end

    # The renderer rewrites short URLs of existing uploads into full ones, so
    # both forms are resolved.
    def upload_for(url)
      url = url.to_s.strip
      return if url.blank?

      if url.start_with?("upload://")
        sha1 = Upload.sha1_from_short_url(url)
        return sha1 && Upload.find_by(sha1:)
      end
      Upload.get_from_url(url)
    rescue URI::Error, ArgumentError
      nil
    end

    def use_upload(upload)
      return false if upload.blank? || !UploadGrants.usable?(upload, @request_context)

      @granted_upload_ids << upload.id
      true
    end
  end
end
