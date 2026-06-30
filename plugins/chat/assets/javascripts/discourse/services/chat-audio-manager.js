import Service from "@ember/service";
import { isTesting } from "discourse/lib/environment";

export const CHAT_SOUNDS = {
  classic: {},
  soft: {},
  retro: {},
  bubble: {},
  ethereal: {},
};

const DEFAULT_SOUND_NAME = "classic";

const THROTTLE_TIME = 3000; // 3 seconds
const MIN_GAIN = 0.001;

let sharedAudioContext;

export function normalizeChatSoundName(name) {
  if (!name) {
    return null;
  }

  return CHAT_SOUNDS[name] ? name : DEFAULT_SOUND_NAME;
}

async function getAudioContext() {
  const AudioContext = window.AudioContext || window.webkitAudioContext;

  if (!sharedAudioContext || sharedAudioContext.state === "closed") {
    sharedAudioContext = new AudioContext();
  }

  if (sharedAudioContext.state === "suspended") {
    await sharedAudioContext.resume();
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

const SOUND_SEQUENCES = {
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

export default class ChatAudioManager extends Service {
  canPlay = true;

  async play(name, { throttle = true, type = "incoming" } = {}) {
    if (!throttle || this.canPlay) {
      await this.#tryPlay(name, type);

      if (!throttle) {
        return;
      }

      this.canPlay = false;
      setTimeout(() => {
        this.canPlay = true;
      }, THROTTLE_TIME);
    }
  }

  async #tryPlay(name, type) {
    try {
      const ctx = await getAudioContext();
      const sequence = SOUND_SEQUENCES[normalizeChatSoundName(name)];
      (sequence[type] || sequence.incoming)(ctx, ctx.currentTime);
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
