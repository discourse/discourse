import Service from "@ember/service";
import { isTesting } from "discourse-common/config/environment";
import { getURLWithCDN } from "discourse-common/lib/get-url";

export const CHAT_SOUNDS = {
  bell: [{ src: "/plugins/chat/audio/bell.mp3", type: "audio/mpeg" }],
  ding: [{ src: "/plugins/chat/audio/ding.mp3", type: "audio/mpeg" }],
};

const DEFAULT_SOUND_NAME = "bell";

const THROTTLE_TIME = 3000; // 3 seconds

export default class ChatAudioManager extends Service {
  canPlay = true;

  async play(name) {
    if (this.canPlay) {
      await this.#tryPlay(name);
      this.canPlay = false;
      setTimeout(() => {
        this.canPlay = true;
      }, THROTTLE_TIME);
    }
  }

  async #tryPlay(name) {
    const src = getURLWithCDN(
      (CHAT_SOUNDS[name] || CHAT_SOUNDS[DEFAULT_SOUND_NAME])[0].src
    );
    const audio = new Audio(src);
    try {
      await audio.play();
    } catch {
      if (!isTesting()) {
        // eslint-disable-next-line no-console
        console.info(
          "[chat] User needs to interact with DOM before we can play notification sounds."
        );
      }
    }
  }
}
