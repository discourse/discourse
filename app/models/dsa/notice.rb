# frozen_string_literal: true

module Dsa
  class Notice
    CONTENT_FIELDS = %w[content_url explanation anonymous name email declaration].freeze
    METADATA_PATTERN = /\n\n<!-- dsa-notice:(\{[^\n]*\}) -->\z/
    private_constant :CONTENT_FIELDS, :METADATA_PATTERN

    attr_reader :post

    def self.find(submission_id:)
      marker = "<!-- dsa-notice:{\"submission_id\":\"#{submission_id}\","
      post =
        Post
          .with_deleted
          .where(user_id: Discourse.system_user.id, post_number: 1)
          .find_by("raw LIKE ?", "%#{marker}%")
      from_post(post)
    end

    def self.from_post(post)
      return unless post && (match = post.raw.match(METADATA_PATTERN))
      new(post:, data: JSON.parse(match[1]))
    end

    def self.create!(attributes:, group:)
      data = attributes.stringify_keys.slice("submission_id", *CONTENT_FIELDS)
      data["reference"] = "DSA-#{SecureRandom.hex(8).upcase}"
      notice = new(data:)
      post =
        PostCreator.create!(
          Discourse.system_user,
          title: I18n.t("dsa_notice.subject", reference: notice.reference),
          raw: notice.raw,
          archetype: Archetype.private_message,
          target_group_names: group.name,
          skip_validations: true,
          skip_jobs: true,
        )
      new(post:, data:)
    end

    def initialize(data:, post: nil)
      @data, @post = data, post
    end

    def reference
      @data.fetch("reference")
    end

    def email
      @data["email"]
    end

    def matches?(attributes)
      @data.slice(*CONTENT_FIELDS) == attributes.stringify_keys.slice(*CONTENT_FIELDS)
    end

    def group_notified?
      @data["group_notified"] == true
    end

    def receipt_sent?
      @data["receipt_sent"] == true
    end

    def mark_group_notified!
      mark("group_notified")
    end

    def mark_receipt_sent!
      mark("receipt_sent")
    end

    def summary(plain_text: false)
      reporter =
        if @data["anonymous"]
          I18n.t("dsa_notice.anonymous")
        elsif plain_text
          "#{@data["name"]} (#{email})"
        else
          "#{escaped(@data["name"])} ([#{escaped(email)}](mailto:#{ERB::Util.url_encode(email)}))"
        end
      I18n.t(
        "dsa_notice.summary",
        reference:,
        content_url: plain_text ? @data.fetch("content_url") : "<#{@data.fetch("content_url")}>",
        explanation: plain_text ? @data.fetch("explanation") : escaped(@data.fetch("explanation")),
        reporter:,
      )
    end

    def raw
      "#{summary}\n\n#{I18n.t("dsa_notice.staff_guidance")}#{metadata}"
    end

    private

    def metadata
      "\n\n<!-- dsa-notice:#{ERB::Util.json_escape(@data.to_json)} -->"
    end

    def escaped(value)
      ERB::Util.html_escape(
        value.gsub(/[\\`*_{}\[\]()#+.!|~=:\/-]/) { |character| "\\#{character}" },
      ).gsub("@", "&#64;")
    end

    def mark(field)
      post.with_lock do
        match = post.raw.match(METADATA_PATTERN)
        @data = JSON.parse(match[1]).merge(field => true)
        post.update_columns(raw: post.raw.sub(METADATA_PATTERN) { metadata })
      end
    end
  end
end
