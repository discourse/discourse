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
    if preserve_markdown_blocks && starts_with_markdown_block?(reason)
      "\n\n**#{label}**\n\n#{reason}"
    else
      "\n\n**#{label}** #{reason.lstrip}"
    end
  end

  def self.starts_with_markdown_block?(reason)
    first_element = Nokogiri::HTML5.fragment(PrettyText.markdown(reason)).element_children.first
    return false unless first_element

    first_element.name != "p" || first_element.at_css("a.onebox").present? ||
      reason.match?(/\A[ \t]*\[[^\r\n]+\]:/)
  end
  private_class_method :starts_with_markdown_block?

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
