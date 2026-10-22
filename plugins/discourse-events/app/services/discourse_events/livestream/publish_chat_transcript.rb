# frozen_string_literal: true

# Once a livestream occurrence ends, its chat is preserved in the event topic,
# provided everyone who can read the topic could already read the chat: in the
# event post for a one-off event, as a dated reply per occurrence otherwise, or
# when the event post has no room left for it.
# The channel is closed when no further occurrences will reuse it.
class DiscourseEvents::Livestream::PublishChatTranscript
  include Service::Base

  # The transcript was sized for the raw it was rendered against, so an edit
  # made meanwhile means rendering it again.
  class EventPostChanged < StandardError
  end

  params do
    attribute :event_date_id, :integer

    validates :event_date_id, presence: true
  end

  policy :chat_enabled
  model :event_date
  model :event
  model :topic_chat_channel

  lock(:topic_chat_channel) do
    transaction do
      step :reload_records

      only_if(:chat_audience_matches_topic_readers) do
        model :event_post_transcript, :render_event_post_transcript, optional: true
        model :transcript, :render_transcript

        only_if(:new_chat_messages) do
          only_if(:appending_to_event_post) { step :append_transcript_to_event_post }
          only_if(:replying) { step :reply_with_transcript }
          step :mark_messages_transcribed
        end
      end
    end
  end

  only_if(:livestream_finished) { step :close_chat_channel }

  private

  def chat_enabled
    SiteSetting.chat_enabled
  end

  def fetch_event_date(params:)
    DiscourseEvents::Events::EventDate.includes(event: { post: :topic }).find_by(
      id: params.event_date_id,
    )
  end

  def fetch_event(event_date:)
    event_date.event if event_date.event&.livestream?
  end

  def fetch_topic_chat_channel(event:)
    DiscourseEvents::Livestream::TopicChatChannel.includes(:chat_channel).find_by(
      topic: event.post.topic,
    )
  end

  def chat_audience_matches_topic_readers(event:, topic_chat_channel:)
    DiscourseEvents::Livestream::ChatTranscriptAudience.new(
      event,
      channel: topic_chat_channel.chat_channel,
    ).matches_topic_readers?
  end

  # Fetched before the lock, so a job that held it may have moved them on.
  # Locking the topic holds off a move to another category, which would change
  # who reads the transcript, until it is written.
  def reload_records(event:, topic_chat_channel:)
    event.post.reload.topic.lock!
    topic_chat_channel.reload
  end

  # Appended to the event post, it shares the length limit with what is there.
  def render_event_post_transcript(event:, event_date:, topic_chat_channel:)
    return if event.recurring?

    transcript =
      build_transcript(
        event:,
        event_date:,
        topic_chat_channel:,
        max_length: SiteSetting.max_post_length - event.post.raw.rstrip.length - 2,
      )
    transcript if transcript.within_length?
  end

  def render_transcript(event_post_transcript:, event:, event_date:, topic_chat_channel:)
    event_post_transcript ||
      build_transcript(
        event:,
        event_date:,
        topic_chat_channel:,
        max_length: SiteSetting.max_post_length,
      )
  end

  def build_transcript(event:, event_date:, topic_chat_channel:, max_length:)
    DiscourseEvents::Livestream::ChatTranscript.new(
      channel: topic_chat_channel.chat_channel,
      messages:
        topic_chat_channel.untranscribed_messages(
          before: next_occurrence_opens_at(event:, event_date:),
        ),
      event_date:,
      max_length:,
    )
  end

  # A late job must leave the chat of the next occurrence to its own transcript.
  def next_occurrence_opens_at(event:, event_date:)
    next_starts_at =
      event.calculate_next_occurrence_from(event_date.starts_at + 1.second)&.dig(:starts_at)
    return if !next_starts_at

    DiscourseEvents::Events::EventDate.new(event:, starts_at: next_starts_at).opens_at
  end

  def new_chat_messages(transcript:)
    transcript.messages?
  end

  def appending_to_event_post(event_post_transcript:)
    event_post_transcript.present?
  end

  def replying(event_post_transcript:)
    event_post_transcript.blank?
  end

  # A record of the stream rather than news, so neither notifies nor bumps.
  def reply_with_transcript(event:, transcript:)
    PostCreator.create!(
      Discourse.system_user,
      topic_id: event.post.topic_id,
      raw: transcript.raw,
      skip_validations: true,
      import_mode: true,
      silent: true,
    )
  end

  def append_transcript_to_event_post(event:, transcript:)
    expected_raw = event.post.raw
    revised =
      PostRevisor.new(event.post).revise!(
        Discourse.system_user,
        {
          raw: "#{expected_raw.rstrip}\n\n#{transcript.raw}",
          edit_reason: I18n.t("discourse_events.livestream.chat.transcript_edit_reason"),
        },
        bypass_bump: true,
        silent: true,
        skip_validations: true,
        skip_staff_log: true,
        expected_raw:,
      )
    raise EventPostChanged if event.post.errors.of_kind?(:base, :edit_conflict)
    fail!(event.post.errors.full_messages.to_sentence) if !revised
  end

  def mark_messages_transcribed(topic_chat_channel:, transcript:)
    topic_chat_channel.update!(last_transcribed_message_id: transcript.last_message_id)
  end

  # Asked of the occurrence that ended rather than of now, as the job may run late.
  def livestream_finished(event:, event_date:)
    !event.occurrences_remaining?(after: event_date.starts_at + 1.second)
  end

  # Only an open channel, so a status set by moderators is kept and the event
  # can tell its own closing apart if it resumes.
  def close_chat_channel(topic_chat_channel:)
    return if !topic_chat_channel.chat_channel.open?

    topic_chat_channel.chat_channel.closed!(Discourse.system_user)
    topic_chat_channel.update!(closed_on_event_end: true)
  end
end
