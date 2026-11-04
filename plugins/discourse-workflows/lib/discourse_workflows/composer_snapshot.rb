# frozen_string_literal: true

module DiscourseWorkflows
  # What a user is writing in the composer when they pause typing or their draft is saved.
  class ComposerSnapshot
    CREATE_TOPIC = "create_topic"
    REPLY = "reply"
    ACTIONS = [CREATE_TOPIC, REPLY].freeze
    DRAFT_ACTIONS = { "createTopic" => CREATE_TOPIC, "reply" => REPLY }.freeze
    # The browser keeps its composer session in the draft, so an autosave's workflow can answer
    # the composer that saved it.
    DRAFT_SESSION_ID_FIELD = "workflowsSessionId"
    MAX_SESSION_ID_LENGTH = 64

    # Attributes are capped so that a tag without its closing bracket can't make
    # scanning quadratic.
    QUOTE_TAG_REGEXP = %r{\[quote(?:=[^\]]{0,300})?\]|\[/quote\]}i
    BLOCKQUOTE_LINE_REGEXP = /^[ \t]*>.*$/
    HTML_COMMENT_START = "<!--"
    HTML_COMMENT_END = "-->"

    attr_reader :user,
                :action,
                :draft_key,
                :session_id,
                :title,
                :raw,
                :category_id,
                :topic,
                :reply_to_post_number

    def self.from_draft(user, draft_key, data)
      return if user.blank? || !data.is_a?(Hash)
      return if data["archetypeId"].to_s == Archetype.private_message

      action = DRAFT_ACTIONS[data["action"].to_s]
      return if action.nil?

      topic = nil
      if action == REPLY
        return if !draft_key.to_s.start_with?(::Draft::EXISTING_TOPIC)
        topic = ::Topic.find_by(id: draft_key.delete_prefix(::Draft::EXISTING_TOPIC).to_i)
        return if topic.nil?
      end

      new(
        user:,
        action:,
        draft_key:,
        session_id: data[DRAFT_SESSION_ID_FIELD],
        title: data["title"],
        raw: data["reply"],
        category_id: data["categoryId"],
        topic:,
        reply_to_post_number: topic && reply_target_post_number(topic, data["postId"]),
      )
    end

    # A reply targets the post it was opened from, saved as `postId`. The composer only lets an
    # edit change `reply_to_post_number`, so a reply's draft always has it empty.
    def self.reply_target_post_number(topic, post_id)
      post_id = Integer(post_id, exception: false)
      topic.posts.where(id: post_id).pick(:post_number) if post_id
    end

    # Drafts can be far longer than a post, so every step here is linear in the text length.
    def self.own_text(raw)
      strip_quotes(strip_html_comments(raw.to_s)).gsub(BLOCKQUOTE_LINE_REGEXP, "")
    end

    def self.strip_html_comments(text)
      parts = []
      position = 0

      while (start = text.index(HTML_COMMENT_START, position))
        finish = text.index(HTML_COMMENT_END, start + HTML_COMMENT_START.length)
        break if finish.nil?

        parts << text[position...start]
        position = finish + HTML_COMMENT_END.length
      end

      parts << text[position..]
      parts.join
    end

    # Removes balanced quote blocks, nested ones included. An unclosed quote is kept as text.
    def self.strip_quotes(text)
      parts = []
      open_quotes = []
      scanner = StringScanner.new(text)

      while (scanned = scanner.scan_until(QUOTE_TAG_REGEXP))
        tag = scanner.matched
        parts << scanned[0, scanned.length - tag.length]

        if tag.start_with?("[/")
          if (start = open_quotes.pop)
            parts.pop(parts.size - start)
          else
            parts << tag
          end
        else
          open_quotes << parts.size
          parts << tag
        end
      end

      parts << scanner.rest
      parts.join
    end

    def initialize(
      user:,
      action:,
      draft_key:,
      raw:,
      session_id: nil,
      title: nil,
      category_id: nil,
      topic: nil,
      reply_to_post_number: nil
    )
      @user = user
      @action = action.to_s
      @draft_key = draft_key.to_s
      if session_id.is_a?(String) && session_id.length <= MAX_SESSION_ID_LENGTH
        @session_id = session_id.presence
      end
      # Matching never looks past what a post can hold.
      @title = title.to_s[0, SiteSetting.max_topic_title_length].presence
      @raw = raw.to_s[0, SiteSetting.max_post_length]
      @category_id = category_id.presence&.to_i
      @topic = topic
      @reply_to_post_number = reply_to_post_number.presence&.to_i
    end

    def reply?
      action == REPLY
    end

    # Replies are filtered by their topic's category.
    def filter_category_id
      reply? ? topic&.category_id : category_id
    end

    def own_text
      @own_text ||= [title, self.class.own_text(raw)].compact_blank.join("\n")
    end

    def composable?
      return @composable if defined?(@composable)

      @composable =
        if user.blank? || ACTIONS.exclude?(action)
          false
        elsif reply?
          # Posting permission comes from the category, so it doesn't cover topics hidden
          # inside it, like shared drafts.
          topic.present? && !topic.private_message? && user.guardian.can_see_topic?(topic) &&
            user.guardian.can_create_post_on_topic?(topic)
        else
          user.guardian.can_create_topic_on_category?(category_id)
        end
    end

    def to_h
      {
        action:,
        draft_key:,
        session_id:,
        title:,
        raw:,
        category_id: filter_category_id,
        topic_id: topic&.id,
        reply_to_post_number:,
      }
    end
  end
end
