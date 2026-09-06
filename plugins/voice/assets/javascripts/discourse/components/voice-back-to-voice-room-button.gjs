import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

// Which room (if any) a thread came from is immutable once the thread is
// created, so both hits and 404s are cached for the page's lifetime — one
// lookup per thread, no matter how often its header re-renders. Transient
// failures are evicted so a network flake can't hide the button for good.
const roomByThread = new Map();

function roomForThread(threadId) {
  if (!roomByThread.has(threadId)) {
    roomByThread.set(
      threadId,
      ajax(`/voice/chat_threads/${threadId}.json`).catch((error) => {
        if (error?.jqXHR?.status !== 404) {
          roomByThread.delete(threadId);
        }
        return null;
      })
    );
  }
  return roomByThread.get(threadId);
}

export default class VoiceBackToVoiceRoomButton extends Component {
  @service router;
  @service siteSettings;

  get thread() {
    return this.args.outletArgs?.thread;
  }

  get shouldLookup() {
    return (
      this.siteSettings.voice_enabled &&
      this.siteSettings.voice_chat_enabled &&
      this.siteSettings.chat_enabled &&
      this.thread?.id &&
      !this.thread.staged
    );
  }

  @bind
  loadRoom(threadId) {
    return roomForThread(threadId);
  }

  @action
  async openRoom(room) {
    const chatActive = await ajax(
      `/voice/chat_threads/${this.thread.id}.json`
    ).then(
      (fresh) => !!fresh.chat_active,
      () => false // If the lookup fails, assume the chat is inactive and let the room page handle it.
    );

    this.router.transitionTo("voice-room", room.slug, {
      queryParams: { join: true, chat: chatActive },
    });
  }

  <template>
    {{#if this.shouldLookup}}
      <DAsyncContent @asyncData={{this.loadRoom}} @context={{this.thread.id}}>
        <:loading></:loading>
        <:content as |room|>
          {{#if room}}
            <DButton
              class="btn-transparent no-text c-navbar__back-to-voice-room"
              @icon="microphone-lines"
              @translatedTitle={{i18n "voice.chat.back_to_voice_room"}}
              @action={{fn this.openRoom room}}
            />
          {{/if}}
        </:content>
      </DAsyncContent>
    {{/if}}
  </template>
}
