# frozen_string_literal: true

module Voice
  class ChatThreadsController < ApplicationController
    # Answers "which voice room did this chat thread come from?" for the
    # back-to-room button chat renders in session thread headers. Every miss —
    # unknown thread, not a session thread, invisible channel or room — is the
    # same 404, so the endpoint reveals nothing about what exists.
    def show
      raise Discourse::NotFound unless Voice::ChatSession.chat_available?

      thread = ::Chat::Thread.find_by(id: params[:id])
      raise Discourse::NotFound if thread.blank?

      # Mirror chat's own thread visibility (Chat::LookupThread): no room info
      # about threads the user couldn't open — invisible channel, threading
      # no longer available, or a deleted starter message (which hides the
      # thread from everyone but channel moderators).
      raise Discourse::NotFound unless guardian.can_preview_chat_channel?(thread.channel)
      raise Discourse::NotFound unless thread.channel.threading_enabled || thread.force
      raise Discourse::NotFound unless original_message_visible?(thread)

      room = Voice::Room.find_by(id: thread.custom_fields[Voice::THREAD_ROOM_ID_FIELD].to_i)
      raise Discourse::NotFound if room.blank?

      # A marker pointing at a room that has since been linked to a different
      # channel is stale — the thread is no longer one of the room's session
      # threads.
      raise Discourse::NotFound if room.chat_channel_id != thread.channel_id
      raise Discourse::NotFound unless guardian.can_see_voice_room?(room)

      render json: {
               id: room.id,
               slug: room.slug,
               name: room.name,
               # Whether this thread is still the room's live session — an
               # ended session's thread links back to the room, but arriving
               # there shouldn't open a chat panel for a conversation that has
               # already rolled over.
               chat_active: Voice::ChatSession.state(room)[:thread_id] == thread.id,
             }
    end

    private

    def original_message_visible?(thread)
      return false if thread.original_message.blank?
      thread.original_message.deleted_at.blank? ||
        guardian.can_moderate_chat?(thread.channel.chatable)
    end
  end
end
