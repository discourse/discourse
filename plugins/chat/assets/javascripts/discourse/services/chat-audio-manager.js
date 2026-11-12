import { cancel } from "@ember/runloop";
import Service from "@ember/service";
import { isTesting } from "discourse/lib/environment";
import discourseLater from "discourse/lib/later";
import { i18n } from "discourse-i18n";

const BUILT_IN_DEFAULT_SOUND = "classic";

const THROTTLE_TIME = 3000; // 3 seconds
const RESUME_TIMEOUT = 500;
const MIN_GAIN = 0.001;

let sharedAudioContext;

async function getAudioContext() {
  const AudioContext = window.AudioContext || window.webkitAudioContext;

  if (!sharedAudioContext || sharedAudioContext.state === "closed") {
    sharedAudioContext = new AudioContext();
  }

  if (sharedAudioContext.state === "suspended") {
    // browsers keep resume() pending until the user interacts with the page;
    // racing a timeout keeps sounds from queuing up and bursting all at once
    // on the next interaction
    let timer;
    try {
      await Promise.race([
        sharedAudioContext.resume().catch(() => {}),
        new Promise((resolve) => {
          timer = discourseLater(resolve, RESUME_TIMEOUT);
        }),
      ]);
    } finally {
      cancel(timer);
    }

    if (sharedAudioContext.state === "suspended") {
      throw new Error("audio context is suspended");
    }
  }

  return sharedAudioContext;
}

function playOscillator(ctx, type, frequency, startTime, duration, maxGain) {
  const oscillator = ctx.createOscillator();
  const gain = ctx.createGain();

  oscillator.type = type;
  oscillator.frequency.value = frequency;
  gain.gain.setValueAtTime(maxGain, startTime);
  gain.gain.exponentialRampToValueAtTime(MIN_GAIN, startTime + duration);

  oscillator.connect(gain).connect(ctx.destination);
  oscillator.start(startTime);
  oscillator.stop(startTime + duration);
}

function playSweep(ctx, options) {
  const oscillator = ctx.createOscillator();
  const gain = ctx.createGain();

  if (options.type) {
    oscillator.type = options.type;
  }

  oscillator.frequency.setValueAtTime(options.from, options.startTime);

  if (options.ramp === "linear") {
    oscillator.frequency.linearRampToValueAtTime(
      options.to,
      options.rampEndTime
    );
  } else {
    oscillator.frequency.exponentialRampToValueAtTime(
      options.to,
      options.rampEndTime
    );
  }

  gain.gain.setValueAtTime(options.gain, options.startTime);
  gain.gain.exponentialRampToValueAtTime(MIN_GAIN, options.endTime);

  oscillator.connect(gain).connect(ctx.destination);
  oscillator.start(options.startTime);
  oscillator.stop(options.endTime);
}

const BUILT_IN_SOUNDS = {
  classic: {
    incoming(ctx, now) {
      playOscillator(ctx, "sine", 587.33, now, 0.1, 0.15);
      playOscillator(ctx, "sine", 783.99, now + 0.1, 0.3, 0.15);
    },

    mention(ctx, now) {
      playOscillator(ctx, "sine", 523.25, now, 0.1, 0.12);
      playOscillator(ctx, "sine", 659.25, now + 0.08, 0.15, 0.12);
      playOscillator(ctx, "sine", 1046.5, now + 0.16, 0.4, 0.15);
    },
  },

  soft: {
    incoming(ctx, now) {
      playOscillator(ctx, "sine", 349.23, now, 0.15, 0.2);
      playOscillator(ctx, "sine", 466.16, now + 0.1, 0.25, 0.2);
    },

    mention(ctx, now) {
      playOscillator(ctx, "sine", 349.23, now, 0.15, 0.2);
      playOscillator(ctx, "sine", 440, now + 0.08, 0.15, 0.2);
      playOscillator(ctx, "sine", 523.25, now + 0.16, 0.3, 0.2);
    },
  },

  retro: {
    incoming(ctx, now) {
      playOscillator(ctx, "square", 392, now, 0.08, 0.04);
      playOscillator(ctx, "square", 493.88, now + 0.08, 0.15, 0.04);
    },

    mention(ctx, now) {
      [523.25, 659.25, 783.99, 1046.5].forEach((frequency, index) => {
        playOscillator(ctx, "square", frequency, now + index * 0.06, 0.1, 0.03);
      });
    },
  },

  bubble: {
    incoming(ctx, now) {
      playSweep(ctx, {
        from: 300,
        to: 700,
        startTime: now,
        rampEndTime: now + 0.1,
        endTime: now + 0.15,
        gain: 0.2,
      });
    },

    mention(ctx, now) {
      playSweep(ctx, {
        from: 400,
        to: 800,
        startTime: now,
        rampEndTime: now + 0.08,
        endTime: now + 0.12,
        gain: 0.15,
      });
      playSweep(ctx, {
        from: 500,
        to: 1000,
        startTime: now + 0.1,
        rampEndTime: now + 0.18,
        endTime: now + 0.25,
        gain: 0.15,
      });
    },
  },

  ethereal: {
    incoming(ctx, now) {
      [523.25, 659.25, 783.99].forEach((frequency) => {
        playOscillator(ctx, "sine", frequency, now, 1.2, 0.05);
      });
    },

    mention(ctx, now) {
      playSweep(ctx, {
        type: "sine",
        ramp: "linear",
        from: 440,
        to: 880,
        startTime: now,
        rampEndTime: now + 0.15,
        endTime: now + 1,
        gain: 0.1,
      });
      playOscillator(ctx, "sine", 1320, now + 0.15, 0.8, 0.03);
    },
  },
};

const sounds = new Map();
let defaultSound;
resetChatSounds();

/**
 * @param {string} name
 * @param {Object} options
 * @param {string|function} options.incoming - audio file URL, or a function receiving `(audioContext, startTime)`
 * @param {string|function} [options.mention] - same as `incoming`, defaults to it
 * @param {string} [options.label] - translation key for the preference option
 * @param {string} [options.translatedLabel] - preference option text
 */
export function registerChatSound(
  name,
  { incoming, mention, label, translatedLabel }
) {
  sounds.set(name, {
    incoming,
    mention,
    label: label ?? `chat.sounds.${name}`,
    translatedLabel,
  });
}

/**
 * @param {string} name - a registered sound, used when the user's choice is
 *   unset or unknown
 */
export function setDefaultChatSound(name) {
  defaultSound = name;
}

export function defaultChatSoundName() {
  // checked on read so the default can be set before its sound is registered
  return sounds.has(defaultSound) ? defaultSound : BUILT_IN_DEFAULT_SOUND;
}

export function resetChatSounds() {
  sounds.clear();
  defaultSound = BUILT_IN_DEFAULT_SOUND;

  Object.entries(BUILT_IN_SOUNDS).forEach(([name, sequence]) =>
    registerChatSound(name, sequence)
  );
}

export function chatSoundOptions() {
  return [...sounds].map(([value, { label, translatedLabel }]) => ({
    name: translatedLabel ?? i18n(label),
    value,
  }));
}

export function normalizeChatSoundName(name) {
  if (!name) {
    return null;
  }

  // also covers sounds from a theme that has since been removed
  return sounds.has(name) ? name : defaultChatSoundName();
}

export default class ChatAudioManager extends Service {
  canPlay = true;

  #throttleTimer;

  // resolves false only when audio could not be produced in this tab (e.g.
  // suspended context); a rate-limited drop is intentional and still counts
  // as handled
  async play(name, { throttle = true, type = "incoming" } = {}) {
    if (throttle) {
      if (!this.canPlay) {
        return true;
      }

      // consume the throttle before awaiting so concurrent calls can't all
      // slip past the check
      this.canPlay = false;
      this.#throttleTimer = discourseLater(() => {
        this.canPlay = true;
      }, THROTTLE_TIME);
    }

    const played = await this.#tryPlay(name, type);

    if (throttle && !played) {
      // a failed attempt played nothing, so it shouldn't burn the window —
      // otherwise alerts arriving in the next 3s report handled and keep
      // their claims without any tab making a sound
      cancel(this.#throttleTimer);
      this.canPlay = true;
    }

    return played;
  }

  async #tryPlay(name, type) {
    const sound = sounds.get(normalizeChatSoundName(name));
    const source = sound[type] || sound.incoming;

    try {
      if (typeof source === "string") {
        // rejects when autoplay is blocked or the file can't be loaded
        await new Audio(source).play();
      } else {
        const ctx = await getAudioContext();
        source(ctx, ctx.currentTime);
      }
      return true;
    } catch {
      if (!isTesting()) {
        // eslint-disable-next-line no-console
        console.info(
          "[chat] User needs to interact with page before we can play notification sounds."
        );
      }
      return false;
    }
  }
}
