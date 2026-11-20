# frozen_string_literal: true

# This is used for formatting Suspension/Silencing messages.
# It can be extended by plugins to provide custom message formats.
class StaffMessageFormat
  def self.reason_section(
    details,
    label_reason: true,
    preserve_markdown_blocks: false,
    locale: I18n.locale
  )
    return "" if details.blank?
    return "\n\n#{details.delete_prefix("\n\n")}" unless label_reason

    label = I18n.t("system_messages.moderation_reason_label", locale:)
    reason = details.sub(/\A(?:[ \t]*\r?\n)+/, "")
    inline = "**#{label}** #{reason.lstrip}"
    if preserve_markdown_blocks && !inline_label_preserves_markdown?(reason, inline)
      "\n\n**#{label}**\n\n#{reason}"
    else
      "\n\n#{inline}"
    end
  end

  def self.inline_label_preserves_markdown?(reason, inline)
    original = Nokogiri::HTML5.fragment(PrettyText.markdown(CGI.unescapeHTML(reason)))
    return true if original.element_children.empty?
    return false if original.element_children.first.name != "p"

    prefixed = Nokogiri::HTML5.fragment(PrettyText.markdown(CGI.unescapeHTML(inline)))
    paragraph = prefixed.element_children.first
    return false unless paragraph&.name == "p"

    label = paragraph.child
    text = label&.next_sibling
    return false unless label&.name == "strong" && text&.text?

    text.content = text.content.delete_prefix(" ")
    label.remove
    original.to_html == prefixed.to_html
  end
  private_class_method :inline_label_preserves_markdown?

  def initialize(type, reason, message = nil)
    @type = type
    @reason = reason
    @message = message

    after_initialize
  end

  # Plugins can overwrite this to munge values before formatting
  def after_initialize
  end

  # Overwrite this to change formatting
  def format
    result = +""
    result << @reason if @reason.present?
    result << "\n\n#{@message}" if @message.present?
    result
  end
end
