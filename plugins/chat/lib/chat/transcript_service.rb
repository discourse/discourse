# frozen_string_literal: true

##
# Used to generate BBCode [chat] tags for the message IDs provided.
#
# If there is > 1 message then the channel name will be shown at
# the top of the first message, and subsequent messages will have
# the chained attribute, which will affect how they are displayed
# in the UI.
#
# Subsequent messages from the same user will be put into the same
# tag. Each new user in the chain of messages will have a new [chat]
# tag created.
#
# A single message will have the channel name displayed to the right
# of the username and datetime of the message.
module Chat
  class TranscriptService
    CHAINED_ATTR = "chained=\"true\""
    MULTIQUOTE_ATTR = "multiQuote=\"true\""
    NO_LINK_ATTR = "noLink=\"true\""

    class TranscriptBBCode
      attr_reader :channel, :multiquote, :chained, :no_link, :include_reactions

      def initialize(
        channel: nil,
        acting_user: nil,
        multiquote: false,
        chained: false,
        no_link: false,
        include_reactions: false
      )
        @channel = channel
        @acting_user = acting_user
        @multiquote = multiquote
        @chained = chained
        @no_link = no_link
        @include_reactions = include_reactions
        @message_data = []
      end

      def add(message:, reactions: nil)
        @message_data << { message: message, reactions: reactions }
      end

      def render
        attrs = [quote_attr(@message_data.first[:message])]

        if channel
          attrs << channel_attr
          attrs << channel_id_attr
        end

        attrs << MULTIQUOTE_ATTR if multiquote
        attrs << CHAINED_ATTR if chained
        attrs << NO_LINK_ATTR if no_link
        attrs << reactions_attr if include_reactions

        <<~MARKDOWN
      [chat #{attrs.compact.join(" ")}]
      #{@message_data.map { |msg| msg[:message].to_markdown }.join("\n\n")}
      [/chat]
      MARKDOWN
      end

      private

      def reactions_attr
        reaction_data =
          @message_data.reduce([]) do |array, msg_data|
            if msg_data[:reactions].any?
              array << msg_data[:reactions].map { |react| "#{react.emoji}:#{react.usernames}" }
            end
            array
          end
        return if reaction_data.empty?
        "reactions=\"#{reaction_data.join(";")}\""
      end

      def quote_attr(message)
        "quote=\"#{message.user.username};#{message.id};#{message.created_at.iso8601}\""
      end

      def channel_attr
        "channel=\"#{channel.title(@acting_user)}\""
      end

      def channel_id_attr
        "channelId=\"#{channel.id}\""
      end
    end

    def initialize(channel, acting_user, messages_or_ids: [], opts: {})
      @channel = channel
      @acting_user = acting_user

      if messages_or_ids.all? { |m| m.is_a?(Numeric) }
        @message_ids = messages_or_ids
      else
        @messages = messages_or_ids
      end
      @opts = opts
    end

    def generate_markdown
      previous_message = nil
      rendered_markdown = []
      all_messages_same_user = messages.count(:user_id) == 1
      open_bbcode_tag =
        TranscriptBBCode.new(
          channel: @channel,
          acting_user: @acting_user,
          multiquote: messages.length > 1,
          chained: !all_messages_same_user,
          no_link: @opts[:no_link],
          include_reactions: @opts[:include_reactions],
        )

      messages.each.with_index do |message, idx|
        if previous_message.present? && previous_message.user_id != message.user_id
          rendered_markdown << open_bbcode_tag.render

          open_bbcode_tag =
            TranscriptBBCode.new(
              acting_user: @acting_user,
              chained: !all_messages_same_user,
              no_link: @opts[:no_link],
              include_reactions: @opts[:include_reactions],
            )
        end

        if @opts[:include_reactions]
          open_bbcode_tag.add(message: message, reactions: reactions_for_message(message))
        else
          open_bbcode_tag.add(message: message)
        end
        previous_message = message
      end

      # tie off the last open bbcode + render
      rendered_markdown << open_bbcode_tag.render
      rendered_markdown.join("\n")
    end

    private

    def messages
      @messages ||=
        Chat::Message
          .includes(:user, upload_references: :upload)
          .where(id: @message_ids, chat_channel_id: @channel.id)
          .order(:created_at)
    end

    ##
    # Queries reactions and returns them in this format
    #
    # emoji   |  usernames  |  chat_message_id
    # ----------------------------------------
    # +1      | foo,bar,baz | 102
    # heart   | foo         | 102
    # sob     | bar,baz     | 103
    def reactions
      @reactions ||= DB.query(<<~SQL, @messages.map(&:id))
    SELECT emoji, STRING_AGG(DISTINCT users.username, ',') AS usernames, chat_message_id
    FROM chat_message_reactions
    INNER JOIN users on users.id = chat_message_reactions.user_id
    WHERE chat_message_id IN (?)
    GROUP BY emoji, chat_message_id
    ORDER BY chat_message_id, emoji
    SQL
    end

    def reactions_for_message(message)
      reactions.select { |react| react.chat_message_id == message.id }
    end
  end
end
