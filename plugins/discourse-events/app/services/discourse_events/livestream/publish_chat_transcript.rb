# frozen_string_literal: true

# Once a livestream occurrence ends, its chat is preserved in the event topic,
# provided everyone who can read the topic could already read the chat: in the
# event post for a one-off event, as a dated reply per occurrence otherwise.
# The channel is closed when no further occurrences will reuse it.
class DiscourseEvents::Livestream::PublishChatTranscript
  include Service::Base

  params do
    attribute :event_date_id, :integer

    validates :event_date_id, presence: true
  end

  policy :chat_enabled
  model :event_date
  model :event
  model :topic_chat_channel

  only_if(:chat_audience_matches_topic_readers) do
    lock(:topic_chat_channel) do
      model :transcript, :render_transcript

      only_if(:new_chat_messages) do
        transaction do
          only_if(:recurring_event) { step :reply_with_transcript }
          only_if(:one_off_event) { step :append_transcript_to_event_post }
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

  # Appended to the event post, it shares the length limit with what is there.
  def render_transcript(event:, event_date:, topic_chat_channel:)
    available_length = SiteSetting.max_post_length
    available_length -= event.post.raw.rstrip.length + 2 if !event.recurring?

    DiscourseEvents::Livestream::ChatTranscript.new(
      channel: topic_chat_channel.chat_channel,
      messages: topic_chat_channel.untranscribed_messages,
      event_date:,
      max_length: available_length,
    )
  end

  def new_chat_messages(transcript:)
    transcript.messages?
  end

  def recurring_event(event:)
    event.recurring?
  end

  def one_off_event(event:)
    !event.recurring?
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
    revised =
      PostRevisor.new(event.post).revise!(
        Discourse.system_user,
        {
          raw: "#{event.post.raw.rstrip}\n\n#{transcript.raw}",
          edit_reason: I18n.t("discourse_events.livestream.chat.transcript_edit_reason"),
        },
        bypass_bump: true,
        silent: true,
        skip_validations: true,
        skip_staff_log: true,
      )
    fail!(event.post.errors.full_messages.to_sentence) if !revised
  end

  def mark_messages_transcribed(topic_chat_channel:, transcript:)
    topic_chat_channel.update!(last_transcribed_message_id: transcript.last_message_id)
  end

  def livestream_finished(event:)
    event.expired?
  end

  def close_chat_channel(topic_chat_channel:)
    topic_chat_channel.chat_channel.closed!(Discourse.system_user)
  end
end
