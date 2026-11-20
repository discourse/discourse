# frozen_string_literal: true

module Chat
  # Server-rendered, paginated view of a channel or thread for crawlers.
  # Channel pages are bucketed by UTC day so a page URL keeps the same messages until
  # retention purges them, rather than every page shifting as the oldest messages are deleted.
  class CrawlerView
    PAGE_SIZE = 50

    attr_reader :channel, :thread, :date, :page

    def initialize(channel:, thread: nil, date: nil, page: nil, target_message_id: nil)
      @channel = channel
      @thread = thread
      @page = [page.to_s.to_i, 1].max
      @valid = true

      @dated = target_message_id.present? || date.present?

      if target_message_id.present?
        locate_message(target_message_id)
      elsif !thread
        @date = date.present? ? parse_date(date) : latest_date
      end
    end

    def valid?
      return false if !@valid
      return true if page == 1 && (thread || date.nil?)

      page <= total_pages && page_scope.exists?
    end

    def messages
      @messages ||=
        page_scope
          .includes(
            :user,
            :revisions,
            :reactions,
            :chat_channel,
            thread: [:channel, { original_message: :user }],
          )
          .order(:created_at, :id)
          .offset((page - 1) * PAGE_SIZE)
          .limit(PAGE_SIZE)
          .to_a
    end

    def total_pages
      @total_pages ||= pages_in(page_scope)
    end

    def title
      if thread
        thread_title
      elsif date
        I18n.t("chat.crawler.channel_day_title", channel: channel.title, date: formatted_date)
      else
        channel.title
      end
    end

    def description
      text = thread ? original_message_excerpt : channel.description
      text.presence || channel.chatable.description_text
    end

    def url
      thread ? thread.url : channel.url
    end

    def canonical_url
      page_url(date, page)
    end

    # When retention will have purged everything on this page, so search engines can drop it on time.
    # Pinned messages are never purged, and they keep the first pages of their day alive.
    def unavailable_after
      retention_days = SiteSetting.chat_channel_retention_days
      return if thread || !@dated || date.nil? || retention_days <= 0

      pinned_count = page_scope.where(id: Chat::PinnedMessage.select(:chat_message_id)).count
      return if pinned_count > (page - 1) * PAGE_SIZE

      day_range(date).end + retention_days.days
    end

    def formatted_date
      I18n.l(date, format: :date_only) if date
    end

    def prev_page_url
      return page_url(date, page - 1) if page > 1
      return if thread || date.nil?

      previous = adjacent_date(:before)
      page_url(previous, pages_in(scope.where(created_at: day_range(previous)))) if previous
    end

    def next_page_url
      return page_url(date, page + 1) if page < total_pages
      return if thread || date.nil?

      following = adjacent_date(:after)
      page_url(following, 1) if following
    end

    def original_message
      thread&.original_message
    end

    def posting_url(message)
      if message.thread&.original_message_id == message.id
        message.thread.url
      else
        "#{Discourse.base_url_no_prefix}#{message.url}"
      end
    end

    # Like the reactions plugin does for posts, each person who reacted counts as one like.
    def like_count(message)
      message.reactions.map(&:user_id).uniq.size
    end

    def reaction_counts(message)
      message.reactions.sort_by(&:created_at).group_by(&:emoji).transform_values(&:size)
    end

    def show_thread_link?(message)
      message_thread = message.thread
      !thread && message_thread&.original_message_id == message.id &&
        (channel.threading_enabled? || message_thread.force) && message_thread.replies_count > 0
    end

    private

    def scope
      @scope ||=
        if thread
          Chat::Message.where(chat_channel_id: channel.id, thread_id: thread.id)
        elsif channel.threading_enabled?
          Chat::Message.where(chat_channel_id: channel.id).where(<<~SQL, channel_id: channel.id)
            chat_messages.thread_id IS NULL OR chat_messages.id IN (
              SELECT original_message_id
              FROM chat_threads
              WHERE chat_threads.channel_id = :channel_id
            )
          SQL
        else
          # Mirrors the channel UI, which only hides replies of forced threads when threading is off.
          Chat::Message
            .where(chat_channel_id: channel.id)
            .left_joins(:thread)
            .where(
              "chat_threads.id IS NULL OR chat_threads.force = false OR chat_messages.id = chat_threads.original_message_id",
            )
        end
    end

    def page_scope
      date ? scope.where(created_at: day_range(date)) : scope
    end

    def pages_in(relation)
      [(relation.count.to_f / PAGE_SIZE).ceil, 1].max
    end

    def day_range(day)
      start = Time.utc(day.year, day.month, day.day)
      start...(start + 1.day)
    end

    def latest_date
      scope.maximum(:created_at)&.utc&.to_date
    end

    def adjacent_date(direction)
      range = day_range(date)
      time =
        if direction == :before
          scope.where("chat_messages.created_at < ?", range.begin).maximum(:created_at)
        else
          scope.where("chat_messages.created_at >= ?", range.end).minimum(:created_at)
        end
      time&.utc&.to_date
    end

    def parse_date(value)
      Date.iso8601(value.to_s)
    rescue ArgumentError
      @valid = false
      nil
    end

    def locate_message(message_id)
      message = scope.find_by(id: message_id)
      return @valid = false if !message

      @date = message.created_at.utc.to_date if !thread
      preceding =
        page_scope.where(
          "(chat_messages.created_at, chat_messages.id) < (?, ?)",
          message.created_at,
          message.id,
        ).count
      @page = (preceding / PAGE_SIZE) + 1
    end

    def page_url(day, number)
      params = {}
      params[:date] = day.iso8601 if day
      params[:page] = number if number > 1
      params.empty? ? url : "#{url}?#{params.to_query}"
    end

    def original_message_excerpt
      excerpt = original_message&.excerpt_for_display
      CGI.unescapeHTML(excerpt) if excerpt.present?
    end

    def thread_title
      thread.title.presence || original_message_excerpt.presence ||
        I18n.t("chat.crawler.thread_title", channel: channel.title)
    end
  end
end
