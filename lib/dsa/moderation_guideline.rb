# frozen_string_literal: true

module Dsa
  class ModerationGuideline
    EMAIL_HEADER = "X-Discourse-Moderation-Guideline"
    DETAILS_CLASS = "moderation-guideline"
    OPENING_TAG = %(<details class="#{DETAILS_CLASS}">)
    DISCLOSURE =
      %r{^#{OPENING_TAG}<summary>[^<]*</summary>(?:<p>(?:[^<]|<br>)*</p>)*</details>(?=\r?$)}
    private_constant :DETAILS_CLASS, :OPENING_TAG, :DISCLOSURE

    def self.selected_rule(classification)
      classification&.dig(:community_rule) if SiteSetting.dsa_reporting_enabled
    end

    def self.append_to(body, rule:, locale:, for_responders: false)
      return body unless rule

      key =
        if for_responders
          "system_messages.moderation_guideline_for_responders"
        else
          "system_messages.moderation_guideline"
        end
      "#{body.rstrip}\n\n#{I18n.t(key, locale:)}\n\n#{disclosure(rule)}"
    end

    def self.email_disclosure?(post)
      post.cooked&.include?(OPENING_TAG) && post.topic.subtype == TopicSubtype.system_message
    end

    def self.email_html(html, post:)
      return html unless html.include?(OPENING_TAG) && email_disclosure?(post)

      fragment = Nokogiri::HTML5.fragment(html)
      details = fragment.css("details.#{DETAILS_CLASS}").last
      details.replace(email_blockquote(details)) if details&.at_css("summary")
      fragment.to_html
    end

    def self.email_html_source(body)
      before, markup, after = body.rpartition(DISCLOSURE)
      return CGI.unescapeHTML(body) if markup.empty?

      details = Nokogiri::HTML5.fragment(markup).at_css("details")
      "#{CGI.unescapeHTML(before)}#{email_blockquote(details).to_html}#{CGI.unescapeHTML(after)}"
    end

    def self.email_plain_text(body)
      before, markup, after = body.rpartition(DISCLOSURE)
      return body if markup.empty?

      details = Nokogiri::HTML5.fragment(markup).at_css("details")
      title = details.at_css("summary").text
      paragraphs = details.css("p")
      paragraphs.css("br").each { |line_break| line_break.replace("\n") }
      lines = paragraphs.map(&:text).join("\n\n").split("\n")
      quote = [title, "", *lines].map { |line| line.empty? ? ">" : "> #{line}" }.join("\n")
      "#{before}#{quote}#{after}"
    end

    def self.email_blockquote(details)
      summary = details.at_css("summary")
      quote = details.document.create_element("blockquote")
      quote.add_child("<p><strong>#{CGI.escapeHTML(summary.text)}</strong></p>")
      summary.remove
      quote.add_child(details.children)
      quote
    end
    private_class_method :email_blockquote

    def self.disclosure(rule)
      ground = rule.fetch(DsaStatementOfRecord::COMMUNITY_RULE_GROUND_KEY).gsub(/\r?\n/, " ")
      explanation =
        rule
          .fetch(DsaStatementOfRecord::COMMUNITY_RULE_EXPLANATION_KEY)
          .gsub("\r\n", "\n")
          .split(/\n{2,}/)
          .map { |paragraph| "<p>#{CGI.escapeHTML(paragraph).gsub("\n", "<br>")}</p>" }
          .join
      %(#{OPENING_TAG}<summary>#{CGI.escapeHTML(ground)}</summary>#{explanation}</details>)
    end
    private_class_method :disclosure
  end
end
