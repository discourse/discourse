# frozen_string_literal: true

module Dsa
  class ModerationGuideline
    PLACEHOLDER = "%{moderation_guideline}"
    DETAILS_CLASS = "moderation-guideline"
    OPENING_TAG = %(<details class="#{DETAILS_CLASS}">)
    DISCLOSURE = %r{^#{OPENING_TAG}.*?</details>$}
    private_constant :DETAILS_CLASS, :OPENING_TAG, :DISCLOSURE

    def self.selected_rule(classification)
      classification&.dig(:community_rule) if SiteSetting.dsa_reporting_enabled
    end

    def self.email_markdown(raw, post:)
      unless raw.include?(OPENING_TAG) && post.cooked.include?(OPENING_TAG) &&
               post.topic.subtype == TopicSubtype.system_message
        return raw
      end

      raw.gsub(DISCLOSURE) do |disclosure|
        details = Nokogiri::HTML5.fragment(disclosure).at_css("details")
        summary = details.at_css("summary")
        next disclosure unless summary

        paragraphs = details.css("p")
        paragraphs.css("br").each { |line_break| line_break.replace("\n") }
        email_quote(summary.text, explanation: paragraphs.map(&:text).join("\n\n"))
      end
    end

    def self.email_html(html, post:)
      unless html.include?(OPENING_TAG) && post.topic.subtype == TopicSubtype.system_message
        return html
      end

      fragment = Nokogiri::HTML5.fragment(html)
      fragment
        .css("details.#{DETAILS_CLASS}")
        .each do |details|
          summary = details.at_css("summary")
          next unless summary

          quote = fragment.document.create_element("blockquote")
          quote.add_child("<p><strong>#{CGI.escapeHTML(summary.text)}</strong></p>")
          summary.remove
          quote.add_child(details.children)
          details.replace(quote)
        end
      fragment.to_html
    end

    def self.email_quote(ground, explanation:)
      title = "**#{escape_markdown(ground)}**"
      lines = explanation.split("\n", -1).map { |line| escape_markdown(line) }
      [title, "", *lines].map { |line| line.empty? ? ">" : "> #{line}" }.join("\n")
    end

    def self.escape_markdown(text)
      text
        .gsub(/[\\\x60*_\[\]<>~|&]/) { |character| "\\#{character}" }
        .sub(/\A(?:\d+[.)]|[-+#])(?=\s|\z)/) { |prefix| "#{prefix[0...-1]}\\#{prefix[-1]}" }
    end
    private_class_method :escape_markdown

    def initialize(rule, locale:, for_responders: false)
      @ground = rule.fetch(DsaStatementOfRecord::COMMUNITY_RULE_GROUND_KEY).gsub(/\r?\n/, " ")
      @explanation =
        rule.fetch(DsaStatementOfRecord::COMMUNITY_RULE_EXPLANATION_KEY).gsub("\r\n", "\n")
      key =
        if for_responders
          "system_messages.moderation_guideline_for_responders"
        else
          "system_messages.moderation_guideline"
        end
      @intro = I18n.t(key, locale:)
    end

    def insert_into(body, email: false)
      rule = email ? self.class.email_quote(@ground, explanation: @explanation) : disclosure
      section = "\n\n#{@intro}\n\n#{rule}"
      if body.include?(PLACEHOLDER)
        body.sub(PLACEHOLDER) { section }
      else
        body.rstrip + section
      end
    end

    private

    def disclosure
      explanation =
        @explanation
          .split(/\n{2,}/)
          .map { |paragraph| "<p>#{CGI.escapeHTML(paragraph).gsub("\n", "<br>")}</p>" }
          .join
      %(#{OPENING_TAG}<summary>#{CGI.escapeHTML(@ground)}</summary>#{explanation}</details>)
    end
  end
end
