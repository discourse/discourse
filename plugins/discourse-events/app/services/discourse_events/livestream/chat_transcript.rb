# frozen_string_literal: true

# Renders the most recent chat messages of a livestream occurrence, keeping only
# as many as fit in `max_length` and pointing to the channel for earlier ones.
# A recurring event's transcript is dated to tell its occurrences apart.
class DiscourseEvents::Livestream::ChatTranscript
  # A quoted message is never shorter than this, which bounds how many could
  # ever fit in a post and so how many need loading.
  MIN_QUOTED_MESSAGE_LENGTH = 50

  WRAP_NAME = "livestream-chat-transcript"

  # A message closing the quote or wrap around it would have the rest of its
  # text cooked as part of a post authored by the system user.
  CLOSING_TAGS = %r{\[/(chat|wrap)\]}i

  def initialize(channel:, messages:, event_date:, max_length:)
    @channel = channel
    @messages = messages
    @event_date = event_date
    @max_length = max_length
  end

  def messages?
    candidates.any?
  end

  def last_message_id
    candidates.last&.id
  end

  def raw
    render(included_count)
  end

  private

  def candidates
    @candidates ||=
      @messages
        .reorder(id: :desc)
        .limit([@max_length / MIN_QUOTED_MESSAGE_LENGTH, 0].max + 1)
        .to_a
        .reverse
  end

  def total_count
    @total_count ||= @messages.count
  end

  # The largest number of most recent messages whose rendering fits, found by
  # bisection since the quote markup makes the length hard to predict. Zero
  # leaves just the pointer to the channel.
  def included_count
    (0..candidates.size).bsearch { |count| !fits?(count + 1) }
  end

  def fits?(count)
    count <= candidates.size && render(count).length <= @max_length
  end

  def render(count)
    I18n.with_locale(SiteSetting.default_locale) do
      [
        heading,
        earlier_messages_notice(total_count - count),
        quotes(candidates.last(count)),
      ].compact.join("\n\n")
    end
  end

  def heading
    if @event_date.event.recurring?
      I18n.t("discourse_events.livestream.chat.transcript_heading_dated", date: occurrence_date)
    else
      I18n.t("discourse_events.livestream.chat.transcript_heading")
    end
  end

  def occurrence_date
    event = @event_date.event
    starts_at = @event_date.starts_at.in_time_zone(event.timezone.presence || "UTC")
    return I18n.l(starts_at.to_date, format: :long) if !SiteSetting.discourse_local_dates_enabled

    time = event.all_day ? "" : " time=#{starts_at.strftime("%H:%M:%S")}"
    "[date=#{starts_at.strftime("%Y-%m-%d")}#{time} timezone=\"#{starts_at.time_zone.tzinfo.name}\"]"
  end

  # Read-only so the escaped text can never be saved back to the message.
  def contained(message)
    message.message = message.message.gsub(CLOSING_TAGS) { "\\#{it}" }
    message.readonly!
    message
  end

  def earlier_messages_notice(count)
    return if count.zero?

    I18n.t(
      "discourse_events.livestream.chat.transcript_earlier_messages",
      count:,
      url: @channel.relative_url,
    )
  end

  # Wrapped so the quotes, one block per speaker, can scroll as a whole.
  def quotes(messages)
    return if messages.empty?

    transcript =
      Chat::TranscriptService.new(
        @channel,
        Discourse.system_user,
        messages_or_ids: messages.map { |message| contained(message) },
      ).generate_markdown

    "[wrap=#{WRAP_NAME}]\n#{transcript}\n[/wrap]"
  end
end
