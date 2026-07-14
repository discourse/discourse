import { cancel } from "@ember/runloop";
import Service, { service } from "@ember/service";
import discourseLater from "discourse/lib/later";
import { i18n } from "discourse-i18n";
import { messageAnnouncementText } from "discourse/plugins/chat/discourse/lib/chat-message-announcement";
import { DEFAULT_SOUND_NAME } from "discourse/plugins/chat/discourse/services/chat-audio-manager";

// a burst is summarized rather than overwriting the shared live region message by message
const ANNOUNCEMENT_INTERVAL_MS = 1000;

// minimum gap between new-message sounds to avoid flooding
const NEW_MESSAGE_SOUND_INTERVAL_MS = 2000;

export default class ChatNewMessageAnnouncer extends Service {
  @service a11y;
  @service chatAudioManager;
  @service currentUser;

  #pendingAnnouncements = [];
  #announcementTimer = null;
  #lastMessageSoundAt = 0;

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.#announcementTimer);
    this.#pendingAnnouncements = [];
  }

  notify(message, { visible, active } = {}) {
    if (
      message.hidden ||
      this.currentUser?.ignored_users?.includes(message.user?.username)
    ) {
      return;
    }

    this.#maybeAnnounce(message, visible);
    this.#maybePlaySound(active);
  }

  #maybeAnnounce(message, visible) {
    if (
      !visible ||
      !this.currentUser?.user_option?.chat_announce_new_messages
    ) {
      return;
    }

    this.#pendingAnnouncements.push(message);
    this.#announcementTimer ??= discourseLater(
      this,
      this.#flushAnnouncements,
      ANNOUNCEMENT_INTERVAL_MS
    );
  }

  #flushAnnouncements() {
    this.#announcementTimer = null;

    const messages = this.#pendingAnnouncements;
    this.#pendingAnnouncements = [];

    if (messages.length === 0) {
      return;
    }

    const announcement =
      messages.length === 1
        ? messageAnnouncementText(messages[0])
        : i18n("chat.screen_reader.new_messages", { count: messages.length });

    this.a11y.announce(announcement, "polite");
  }

  #maybePlaySound(active) {
    if (
      !active ||
      !this.currentUser?.user_option?.chat_new_message_sound ||
      this.currentUser.isInDoNotDisturb()
    ) {
      return;
    }

    const now = Date.now();
    if (now - this.#lastMessageSoundAt < NEW_MESSAGE_SOUND_INTERVAL_MS) {
      return;
    }
    this.#lastMessageSoundAt = now;

    // fall back to the default when no sound is selected.
    const sound = this.currentUser.chat_sound || DEFAULT_SOUND_NAME;
    // throttle false so this doesn't consume the shared chat-audio throttle
    this.chatAudioManager.play(sound, { throttle: false });
  }
}
