import Service from "@ember/service";
import { isTesting } from "discourse-common/config/environment";
import { getURLWithCDN } from "discourse-common/lib/get-url";

export const CHAT_SOUNDS = {
  bell: [{ src: "/plugins/chat/audio/bell.mp3", type: "audio/mpeg" }],
  ding: [{ src: "/plugins/chat/audio/ding.mp3", type: "audio/mpeg" }],
};

const DEFAULT_SOUND_NAME = "bell";

const createAudioCache = (sources) => {
  const audio = new Audio();
  audio.pause();
  sources.forEach(({ type, src }) => {
    const source = document.createElement("source");
    source.type = type;
    source.src = getURLWithCDN(src);
    audio.appendChild(source);
  });
  return audio;
};

export default class ChatAudioManager extends Service {
  _audioCache = {};

  setup() {
    Object.keys(CHAT_SOUNDS).forEach((soundName) => {
      this._audioCache[soundName] = createAudioCache(CHAT_SOUNDS[soundName]);
    });
  }

  willDestroy() {
    super.willDestroy(...arguments);

    this._audioCache = {};
  }

  async play(soundName) {
    if (isTesting()) {
      return;
    }

    const audio =
      this._audioCache[soundName] || this._audioCache[DEFAULT_SOUND_NAME];

    if (!audio.paused) {
      audio.pause();
      if (typeof audio.fastSeek === "function") {
        audio.fastSeek(0);
      } else {
        audio.currentTime = 0;
      }
    }

    try {
      await audio.play();
    } catch (e) {
      if (!isTesting()) {
        // eslint-disable-next-line no-console
        console.info(
          "[chat] User needs to interact with DOM before we can play notification sounds."
        );
      }
    }
  }
}
