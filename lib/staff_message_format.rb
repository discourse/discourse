# frozen_string_literal: true

# This is used for formatting Suspension/Silencing messages.
# It can be extended by plugins to provide custom message formats.
class StaffMessageFormat
  MARKDOWN_BLOCK_START =
    /
    \A(?:
      [ ]{4} | \t |
      [ ]{0,3}(?:
        \[[^\r\n]+\]: | > | `{3} | ~{3} | \#{1,6}(?:\s|\z) |
        (?:[-+*]|\d{1,9}[.)])\s |
        (?:-[ \t]*){3,}(?:\r?\n|\z) |
        (?:\*[ \t]*){3,}(?:\r?\n|\z) |
        (?:_[ \t]*){3,}(?:\r?\n|\z)
      )
    )
  /x

  private_constant :MARKDOWN_BLOCK_START

  def self.reason_section(details, label_reason: true, locale: I18n.locale)
    return "" if details.blank?
    return "\n\n#{details.delete_prefix("\n\n")}" unless label_reason

    label = I18n.t("system_messages.moderation_reason_label", locale:)
    reason = details.sub(/\A(?:[ \t]*\r?\n)+/, "")
    if MARKDOWN_BLOCK_START.match?(reason)
      "\n\n**#{label}**\n\n#{reason}"
    else
      "\n\n**#{label}** #{reason.lstrip}"
    end
  end

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
