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
      attr_reader :channel,
                  :multiquote,
                  :chained,
                  :no_link,
                  :include_reactions,
                  :thread_id,
                  :thread_ranges

      def initialize(
        channel: nil,
        acting_user: nil,
        multiquote: false,
        chained: false,
        no_link: false,
        include_reactions: false,
        thread_id: nil,
        thread_ranges: {}
      )
        @channel = channel
        @acting_user = acting_user
        @multiquote = multiquote
        @chained = chained
        @no_link = no_link
        @include_reactions = include_reactions
        @thread_ranges = thread_ranges
        @message_data = []
        @threads_markdown = {}
        @thread_id = thread_id
      end

      def add(message:, reactions: nil)
        @message_data << { message: message, reactions: reactions }
      end

      def add_thread_markdown(thread_id:, markdown:)
        @threads_markdown[thread_id] = markdown
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

        if thread_id
          message = @message_data.first[:message]
          thread = Chat::Thread.find(thread_id)

          if thread.present? && thread.replies_count > 0
            attrs << thread_id_attr
            attrs << thread_title_attr(message, thread)
          end
        end

        <<~MARKDOWN
      [chat #{attrs.compact.join(" ")}]
      #{render_messages}
      [/chat]
      MARKDOWN
      end

      private

      def render_messages
        @message_data
          .map do |msg_data|
            rendered_message = msg_data[:message].to_markdown

            if msg_data[:message].thread_id.present?
              thread_data = @threads_markdown[msg_data[:message].thread_id]

              if thread_data.present?
                rendered_message + "\n\n" + thread_data
              else
                rendered_message
              end
            else
              rendered_message
            end
          end
          .join("\n\n")
      end

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

      def thread_id_attr
        "threadId=\"#{thread_id}\""
      end

      def thread_title_attr(message, thread)
        range = thread_ranges[message.id] if thread_ranges.has_key?(message.id)

        thread_title =
          thread.title.present? ? thread.title : I18n.t("chat.transcript.default_thread_title")
        thread_title += " (#{range})" if range.present?
        "threadTitle=\"#{thread_title}\""
      end
    end

    def initialize(channel, acting_user, messages_or_ids: [], thread_ranges: {}, opts: {})
      @channel = channel
      @acting_user = acting_user

      if messages_or_ids.all? { |m| m.is_a?(Numeric) }
        @message_ids = messages_or_ids
      else
        @messages = messages_or_ids
      end
      @opts = opts
      @thread_ranges = thread_ranges
    end

    def generate_markdown
      previous_message = nil
      rendered_markdown = []
      rendered_thread_markdown = []
      threading_enabled = @channel.threading_enabled?
      thread_id = threading_enabled ? messages.first.thread_id : nil
      thread = Chat::Thread.find_by(id: thread_id) if thread_id.present? && threading_enabled

      # We are getting only the OP of the thread, let's expand it to
      # include all the replies for the thread.
      if messages.count == 1 && thread&.original_message_id == messages.first.id
        @messages = [messages.first] + messages.first.thread.replies
      end

      all_messages_same_user = messages.map(&:user_id).uniq.count == 1

      open_bbcode_tag =
        TranscriptBBCode.new(
          channel: @channel,
          acting_user: @acting_user,
          multiquote: messages.length > 1,
          chained: !all_messages_same_user,
          no_link: @opts[:no_link],
          thread_id: thread_id,
          thread_ranges: @thread_ranges,
          include_reactions: @opts[:include_reactions],
        )

      (threading_enabled ? group_messages(messages) : messages).each do |message_data|
        message = threading_enabled ? message_data.first : message_data

        user_changed = previous_message&.user_id != message.user_id
        thread_changed = threading_enabled && previous_message&.thread_id != message.thread_id

        if previous_message.present? && (user_changed || thread_changed)
          rendered_markdown << open_bbcode_tag.render
          thread_id = threading_enabled ? message.thread_id : nil

          open_bbcode_tag =
            TranscriptBBCode.new(
              acting_user: @acting_user,
              chained: !all_messages_same_user,
              no_link: @opts[:no_link],
              thread_id: thread_id,
              thread_ranges: @thread_ranges,
              include_reactions: @opts[:include_reactions],
            )
        end

        if @opts[:include_reactions]
          open_bbcode_tag.add(message: message, reactions: reactions_for_message(message))
        else
          open_bbcode_tag.add(message: message)
        end

        previous_message = message
        next if !threading_enabled

        if message_data.length > 1
          previous_thread_message = nil
          rendered_thread_markdown.clear

          thread_bbcode_tag =
            TranscriptBBCode.new(
              acting_user: @acting_user,
              chained: !all_messages_same_user,
              no_link: @opts[:no_link],
              include_reactions: @opts[:include_reactions],
            )

          message_data[1..].each do |thread_message|
            if previous_thread_message.present? &&
                 previous_thread_message.user_id != thread_message.user_id
              rendered_thread_markdown << thread_bbcode_tag.render

              thread_bbcode_tag =
                TranscriptBBCode.new(
                  acting_user: @acting_user,
                  chained: !all_messages_same_user,
                  no_link: @opts[:no_link],
                  include_reactions: @opts[:include_reactions],
                )
            end

            if @opts[:include_reactions]
              thread_bbcode_tag.add(
                message: thread_message,
                reactions: reactions_for_message(thread_message),
              )
            else
              thread_bbcode_tag.add(message: thread_message)
            end
            previous_thread_message = thread_message
          end
          rendered_thread_markdown << thread_bbcode_tag.render
        end
        thread_id = message_data.first.thread_id
        if thread_id.present?
          thread = Chat::Thread.find(thread_id)
          if thread&.replies_count&.> 0
            open_bbcode_tag.add_thread_markdown(
              thread_id: thread_id,
              markdown: rendered_thread_markdown.join("\n"),
            )
          end
        end
      end

      # tie off the last open bbcode + render
      rendered_markdown << open_bbcode_tag.render
      rendered_markdown.join("\n")
    end

    private

    def group_messages(messages)
      messages.group_by { |msg| msg.thread_id || msg.id }.values
    end

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
