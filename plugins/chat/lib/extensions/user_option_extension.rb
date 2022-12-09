# frozen_string_literal: true

module Chat::UserOptionExtension
  # TODO: remove last_emailed_for_chat and chat_isolated in 2023
  def self.prepended(base)
    if base.ignored_columns
      base.ignored_columns = base.ignored_columns + %i[last_emailed_for_chat chat_isolated]
    else
      base.ignored_columns = %i[last_emailed_for_chat chat_isolated]
    end

    def base.chat_email_frequencies
      @chat_email_frequencies ||= { never: 0, when_away: 1 }
    end

    base.enum :chat_email_frequency, base.chat_email_frequencies, prefix: "send_chat_email"
  end
end
