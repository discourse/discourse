# frozen_string_literal: true

module Chat
  module UserOptionExtension
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

      def base.chat_header_indicator_preferences
        @chat_header_indicator_preferences ||= { all_new: 0, dm_and_mentions: 1, never: 2 }
      end

      base.enum :chat_email_frequency, base.chat_email_frequencies, prefix: "send_chat_email"
      base.enum :chat_header_indicator_preference, base.chat_header_indicator_preferences
    end
  end
end
