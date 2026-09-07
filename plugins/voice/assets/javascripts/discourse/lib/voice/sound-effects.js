import { RING_SECONDS } from "./call-constants";

let sharedCtx = null;

async function getAudioContext() {
  if (!sharedCtx || sharedCtx.state === "closed") {
    sharedCtx = new AudioContext();
  }
  if (sharedCtx.state === "suspended") {
    await sharedCtx.resume();
  }
  return sharedCtx;
}

const CUE_PATTERNS = {
  connected: {
    direction: "up",
    notes: [
      { frequency: 523.25, offset: 0, duration: 0.15, gain: 0.15 },
      { frequency: 659.25, offset: 0.1, duration: 0.15, gain: 0.15 },
    ],
  },
  disconnected: {
    direction: "down",
    notes: [
      { frequency: 659.25, offset: 0, duration: 0.15, gain: 0.15 },
      { frequency: 523.25, offset: 0.1, duration: 0.15, gain: 0.15 },
    ],
  },
  joined: {
    direction: "up",
    notes: [{ frequency: 659.25, offset: 0, duration: 0.1, gain: 0.12 }],
  },
  left: {
    direction: "down",
    notes: [{ frequency: 523.25, offset: 0, duration: 0.1, gain: 0.12 }],
  },
  muted: {
    direction: "down",
    notes: [{ frequency: 392, offset: 0, duration: 0.08, gain: 0.1 }],
  },
  unmuted: {
    direction: "up",
    notes: [{ frequency: 440, offset: 0, duration: 0.08, gain: 0.1 }],
  },
  deafened: {
    direction: "down",
    notes: [
      { frequency: 392, offset: 0, duration: 0.07, gain: 0.1 },
      { frequency: 293.66, offset: 0.07, duration: 0.07, gain: 0.1 },
    ],
  },
  undeafened: {
    direction: "up",
    notes: [
      { frequency: 293.66, offset: 0, duration: 0.07, gain: 0.1 },
      { frequency: 392, offset: 0.07, duration: 0.07, gain: 0.1 },
    ],
  },
};

async function playCue(cueName, soundName) {
  try {
    const ctx = await getAudioContext();
    const theme = SOUND_THEMES[normalizeSoundName(soundName)];
    theme.cue(ctx, ctx.destination, CUE_PATTERNS[cueName], ctx.currentTime);
  } catch {
    // audio not available
  }
}

export function playConnectedSound(soundName) {
  return playCue("connected", soundName);
}

export function playDisconnectedSound(soundName) {
  return playCue("disconnected", soundName);
}

export function playUserJoinedSound(soundName) {
  return playCue("joined", soundName);
}

export function playUserLeftSound(soundName) {
  return playCue("left", soundName);
}

export function playMuteSound(soundName) {
  return playCue("muted", soundName);
}

export function playUnmuteSound(soundName) {
  return playCue("unmuted", soundName);
}

export function playDeafenSound(soundName) {
  return playCue("deafened", soundName);
}

export function playUndeafenSound(soundName) {
  return playCue("undeafened", soundName);
}

let ringtoneTimer = null;
let waitingTimer = null;

export const DEFAULT_SOUND_NAME = "classic";

const MIN_GAIN = 0.001;
const CALL_SOUND_START_DELAY = 0.05;

function playCallOscillator(
  ctx,
  output,
  { type = "sine", frequency, startTime, duration, gain: maxGain, attack = 0 }
) {
  const oscillator = ctx.createOscillator();
  const gain = ctx.createGain();

  oscillator.type = type;
  oscillator.frequency.value = frequency;
  if (attack > 0) {
    gain.gain.setValueAtTime(MIN_GAIN, startTime);
    gain.gain.linearRampToValueAtTime(maxGain, startTime + attack);
  } else {
    gain.gain.setValueAtTime(maxGain, startTime);
  }
  gain.gain.exponentialRampToValueAtTime(MIN_GAIN, startTime + duration);

  oscillator.connect(gain).connect(output);
  oscillator.start(startTime);
  oscillator.stop(startTime + duration + 0.02);
}

function playCallSweep(
  ctx,
  output,
  { type = "sine", from, to, startTime, rampDuration, duration, gain: maxGain }
) {
  const oscillator = ctx.createOscillator();
  const gain = ctx.createGain();

  oscillator.type = type;
  oscillator.frequency.setValueAtTime(from, startTime);
  oscillator.frequency.exponentialRampToValueAtTime(
    to,
    startTime + rampDuration
  );
  gain.gain.setValueAtTime(maxGain, startTime);
  gain.gain.exponentialRampToValueAtTime(MIN_GAIN, startTime + duration);

  oscillator.connect(gain).connect(output);
  oscillator.start(startTime);
  oscillator.stop(startTime + duration + 0.02);
}

function playClassicCue(ctx, output, pattern, startTime) {
  pattern.notes.forEach(({ offset, ...note }) => {
    playCallOscillator(ctx, output, {
      ...note,
      startTime: startTime + offset,
    });
  });
}

function playSoftCue(ctx, output, pattern, startTime) {
  pattern.notes.forEach(({ frequency, offset, duration, gain }) => {
    playCallOscillator(ctx, output, {
      frequency: frequency * (2 / 3),
      startTime: startTime + offset * 1.2,
      duration: duration * 1.5,
      gain: gain * 0.85,
      attack: 0.025,
    });
  });
}

function playRetroCue(ctx, output, pattern, startTime) {
  pattern.notes.forEach(({ frequency, offset, duration, gain }) => {
    playCallOscillator(ctx, output, {
      type: "square",
      frequency,
      startTime: startTime + offset * 0.8,
      duration: Math.max(duration * 0.8, 0.06),
      gain: gain * 0.28,
    });
  });
}

function playBubbleCue(ctx, output, pattern, startTime) {
  const rises = pattern.direction === "up";

  pattern.notes.forEach(({ frequency, offset, duration, gain }) => {
    const sweepDuration = Math.max(duration * 1.4, 0.12);
    playCallSweep(ctx, output, {
      from: frequency * (rises ? 0.72 : 1.28),
      to: frequency * (rises ? 1.18 : 0.82),
      startTime: startTime + offset,
      rampDuration: sweepDuration * 0.65,
      duration: sweepDuration,
      gain: gain * 0.85,
    });
  });
}

function playEtherealCue(ctx, output, pattern, startTime) {
  pattern.notes.forEach(({ frequency, offset, duration, gain }) => {
    playCallOscillator(ctx, output, {
      frequency,
      startTime: startTime + offset * 1.4,
      duration: Math.max(duration * 2.8, 0.28),
      gain: gain * 0.4,
      attack: 0.05,
    });
  });
}

const SOUND_THEMES = {
  classic: {
    cue: playClassicCue,
    ringtone(ctx, output, startTime) {
      const notes = [523.25, 659.25, 783.99, 1046.5];
      [0, 0.45].forEach((offset) => {
        notes.forEach((frequency, index) => {
          playCallOscillator(ctx, output, {
            frequency,
            startTime: startTime + offset + index * 0.075,
            duration: index === 3 ? 0.22 : 0.12,
            gain: 0.14,
          });
        });
      });
    },
    ringtoneCycle: 1.7,

    waiting(ctx, output, startTime) {
      playCallOscillator(ctx, output, {
        frequency: 523.25,
        startTime,
        duration: 1.1,
        gain: 0.12,
        attack: 0.08,
      });
      playCallOscillator(ctx, output, {
        frequency: 659.25,
        startTime: startTime + 0.04,
        duration: 1.1,
        gain: 0.12,
        attack: 0.08,
      });
    },
    waitingCycle: 2,
  },

  soft: {
    cue: playSoftCue,
    ringtone(ctx, output, startTime) {
      [0, 0.68].forEach((offset) => {
        [349.23, 440, 523.25].forEach((frequency, index) => {
          playCallOscillator(ctx, output, {
            frequency,
            startTime: startTime + offset + index * 0.11,
            duration: index === 2 ? 0.45 : 0.28,
            gain: 0.12,
          });
        });
      });
    },
    ringtoneCycle: 2.1,

    waiting(ctx, output, startTime) {
      playCallOscillator(ctx, output, {
        frequency: 349.23,
        startTime,
        duration: 1.15,
        gain: 0.1,
        attack: 0.1,
      });
      playCallOscillator(ctx, output, {
        frequency: 466.16,
        startTime: startTime + 0.08,
        duration: 1.05,
        gain: 0.09,
        attack: 0.1,
      });
    },
    waitingCycle: 2.1,
  },

  retro: {
    cue: playRetroCue,
    ringtone(ctx, output, startTime) {
      [0, 0.42].forEach((offset) => {
        [392, 493.88, 587.33, 783.99].forEach((frequency, index) => {
          playCallOscillator(ctx, output, {
            type: "square",
            frequency,
            startTime: startTime + offset + index * 0.07,
            duration: index === 3 ? 0.16 : 0.1,
            gain: 0.035,
          });
        });
      });
    },
    ringtoneCycle: 1.55,

    waiting(ctx, output, startTime) {
      [0, 0.18].forEach((offset, index) => {
        playCallOscillator(ctx, output, {
          type: "square",
          frequency: index === 0 ? 392 : 493.88,
          startTime: startTime + offset,
          duration: 0.14,
          gain: 0.025,
        });
      });
    },
    waitingCycle: 1.3,
  },

  bubble: {
    cue: playBubbleCue,
    ringtone(ctx, output, startTime) {
      [0, 0.48].forEach((offset) => {
        playCallSweep(ctx, output, {
          from: 300,
          to: 700,
          startTime: startTime + offset,
          rampDuration: 0.1,
          duration: 0.16,
          gain: 0.13,
        });
        playCallSweep(ctx, output, {
          from: 420,
          to: 980,
          startTime: startTime + offset + 0.13,
          rampDuration: 0.11,
          duration: 0.18,
          gain: 0.11,
        });
      });
    },
    ringtoneCycle: 1.55,

    waiting(ctx, output, startTime) {
      playCallSweep(ctx, output, {
        from: 280,
        to: 620,
        startTime,
        rampDuration: 0.22,
        duration: 0.42,
        gain: 0.09,
      });
    },
    waitingCycle: 1.5,
  },

  ethereal: {
    cue: playEtherealCue,
    ringtone(ctx, output, startTime) {
      [523.25, 659.25, 783.99].forEach((frequency) => {
        playCallOscillator(ctx, output, {
          frequency,
          startTime,
          duration: 1.4,
          gain: 0.045,
          attack: 0.12,
        });
      });
      playCallSweep(ctx, output, {
        from: 880,
        to: 1320,
        startTime: startTime + 0.18,
        rampDuration: 0.3,
        duration: 1.05,
        gain: 0.035,
      });
    },
    ringtoneCycle: 2.15,

    waiting(ctx, output, startTime) {
      [440, 554.37, 659.25].forEach((frequency) => {
        playCallOscillator(ctx, output, {
          frequency,
          startTime,
          duration: 1.65,
          gain: 0.035,
          attack: 0.18,
        });
      });
    },
    waitingCycle: 2.4,
  },
};

export function normalizeSoundName(name) {
  return SOUND_THEMES[name] ? name : DEFAULT_SOUND_NAME;
}

// The loops stop themselves at the ring window so no caller has to remember
// to. Explicit stops (answer, decline, hang up) come sooner.
const MAX_CALL_LOOP_MS = RING_SECONDS * 1000;

// Bumped on every start/stop so an in-flight start that was parked on an
// AudioContext await can tell it has been superseded and must not begin
// playing (e.g. a ringtone start that only unblocks once the user joins).
let callSoundGeneration = 0;

// All loop audio routes through this node so stopping can silence tones the
// scheduler already queued, not just cancel the next cycle.
let callLoopGain = null;

// Ringing is triggered by a MessageBus event, not a user gesture. Without a
// prior gesture the context may not only refuse to resume — resume() can sit
// pending until the next gesture, so awaiting it outright would start the
// sound at whatever the user does next. Race it against a short timeout and
// report the state we actually reached.
async function runningAudioContext() {
  if (!sharedCtx || sharedCtx.state === "closed") {
    sharedCtx = new AudioContext();
  }
  if (sharedCtx.state === "suspended") {
    await Promise.race([
      sharedCtx.resume().catch(() => {}),
      new Promise((resolve) => setTimeout(resolve, 300)),
    ]);
  }
  return sharedCtx.state === "running" ? sharedCtx : null;
}

// Warms up the shared AudioContext inside a user gesture so sounds scheduled
// after later awaits (e.g. once a call request round-trips) still play.
export function unlockAudio() {
  getAudioContext().catch(() => {});
}

/**
 * Start the looping incoming-call ringtone on the callee's device.
 *
 * @param {string} [soundName] the listener's chat notification sound name
 * @returns {Promise<boolean>} whether audio is actually playing
 */
export async function startRingtone(soundName) {
  stopCallSounds();
  const generation = ++callSoundGeneration;
  try {
    const ctx = await runningAudioContext();
    if (!ctx || generation !== callSoundGeneration) {
      return false;
    }

    const output = ctx.createGain();
    output.connect(ctx.destination);
    callLoopGain = output;

    let nextTime = ctx.currentTime + CALL_SOUND_START_DELAY;
    const startedAt = Date.now();
    const theme = SOUND_THEMES[normalizeSoundName(soundName)];

    const schedule = () => {
      if (!ringtoneTimer || generation !== callSoundGeneration) {
        return;
      }
      if (Date.now() - startedAt >= MAX_CALL_LOOP_MS) {
        stopCallSounds();
        return;
      }

      theme.ringtone(ctx, output, nextTime);
      nextTime += theme.ringtoneCycle;

      ringtoneTimer = setTimeout(
        schedule,
        Math.max((theme.ringtoneCycle - 0.2) * 1000, 200)
      );
    };

    ringtoneTimer = true;
    schedule();
    return true;
  } catch {
    return false;
  }
}

/**
 * Start the looping waiting (ringback) tone on the caller's device.
 *
 * @param {number} [maxDurationMs] cap below the full ring window, e.g. when
 *   resuming partway through an already-running ring
 * @param {string} [soundName] the listener's chat notification sound name
 * @returns {Promise<boolean>} whether audio is actually playing
 */
export async function startWaitingSound(
  maxDurationMs = MAX_CALL_LOOP_MS,
  soundName
) {
  stopCallSounds();
  const generation = ++callSoundGeneration;
  const capMs = Math.min(maxDurationMs, MAX_CALL_LOOP_MS);
  if (capMs <= 0) {
    return false;
  }
  try {
    const ctx = await runningAudioContext();
    if (!ctx || generation !== callSoundGeneration) {
      return false;
    }

    const output = ctx.createGain();
    output.connect(ctx.destination);
    callLoopGain = output;

    let nextTime = ctx.currentTime + CALL_SOUND_START_DELAY;
    const startedAt = Date.now();
    const theme = SOUND_THEMES[normalizeSoundName(soundName)];

    const schedule = () => {
      if (!waitingTimer || generation !== callSoundGeneration) {
        return;
      }
      if (Date.now() - startedAt >= capMs) {
        stopCallSounds();
        return;
      }

      theme.waiting(ctx, output, nextTime);
      nextTime += theme.waitingCycle;

      waitingTimer = setTimeout(
        schedule,
        Math.max((theme.waitingCycle - 0.2) * 1000, 200)
      );
    };

    waitingTimer = true;
    schedule();
    return true;
  } catch {
    return false;
  }
}

/**
 * Stop whichever call loop (ringtone or waiting tone) is active.
 */
export function stopCallSounds() {
  // Invalidates starts still parked on the AudioContext await, so a ringtone
  // blocked on a missing user gesture can't begin playing after the fact.
  callSoundGeneration++;

  if (ringtoneTimer) {
    clearTimeout(ringtoneTimer);
    ringtoneTimer = null;
  }
  if (waitingTimer) {
    clearTimeout(waitingTimer);
    waitingTimer = null;
  }

  // Cutting the loop's shared output silences tones already scheduled on the
  // context, which cancelling the next cycle alone would let ring out.
  if (callLoopGain) {
    try {
      callLoopGain.disconnect();
    } catch {
      // already disconnected
    }
    callLoopGain = null;
  }
}

export function resetSoundEffectsForTesting() {
  stopCallSounds();
  try {
    sharedCtx?.close?.();
  } catch {
    // already closed
  }
  sharedCtx = null;
}

export function schedulePlaybackResume(element, pendingPlaybackElements) {
  if (
    !element ||
    typeof document === "undefined" ||
    pendingPlaybackElements.has(element)
  ) {
    return;
  }

  pendingPlaybackElements.add(element);

  const resume = () => {
    try {
      element.play?.();
    } catch {
      // ignore subsequent failures
    }

    document.removeEventListener("pointerdown", resume);
    document.removeEventListener("keydown", resume);
    pendingPlaybackElements.delete(element);
  };

  document.addEventListener("pointerdown", resume, { once: true });
  document.addEventListener("keydown", resume, { once: true });
}
