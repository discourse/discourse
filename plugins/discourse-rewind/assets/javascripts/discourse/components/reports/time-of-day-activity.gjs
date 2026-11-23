import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import { barsFor } from "discourse/plugins/discourse-rewind/discourse/lib/rewind-bars";
import { i18nForOwner } from "discourse/plugins/discourse-rewind/discourse/lib/rewind-i18n";

const PEAK_WINDOW = 0.2;
const BIT_CRUSH_STEPS = 5;
const LAST_HOUR = 23;

function triangleWave(frequency, time) {
  return (2 / Math.PI) * Math.asin(Math.sin(2 * Math.PI * frequency * time));
}

function activityAt(activityByHour, fractionalHour) {
  const hour = Math.floor(fractionalHour);
  const current = activityByHour[hour];
  const next = activityByHour[Math.min(hour + 1, LAST_HOUR)];
  return current + (next - current) * (fractionalHour - hour);
}

export default class TimeOfDayActivity extends Component {
  @tracked isPlaying = false;
  @tracked playbackProgress = 0;

  audioContext = null;
  audioSource = null;
  playbackTimeout = null;
  stereoPanner = null;
  animationFrame = null;

  get activityByHour() {
    return this.args.report.data.activity_by_hour;
  }

  get mostActiveHour() {
    return this.args.report.data.most_active_hour;
  }

  get maxActivity() {
    return Math.max(...this.activityByHour, 1);
  }

  get personalizedAudioParams() {
    const username = this.args.user?.username || "default";

    // convert username to seed
    const hash = (str) => {
      let h = 0;
      for (let i = 0; i < str.length; i++) {
        h = (h * 31 + str.charCodeAt(i)) | 0; // eslint-disable-line no-bitwise
      }
      return Math.abs(h);
    };

    const seed = hash(username);

    // Three distinct scales for variety
    const scales = [
      // C minor pentatonic
      [
        130.81, 155.56, 174.61, 196.0, 233.08, 261.63, 311.13, 349.23, 392.0,
        466.16, 523.25,
      ],
      // C major pentatonic
      [
        130.81, 146.83, 164.81, 196.0, 220.0, 261.63, 293.66, 329.63, 392.0,
        440.0, 523.25,
      ],
      // Blues scale
      [
        130.81, 155.56, 164.81, 174.61, 196.0, 233.08, 261.63, 311.13, 329.63,
        349.23, 392.0,
      ],
    ];

    const harmonyRatios = [1.5, 1.25, 2.0]; // Perfect fifth, major third, octave

    return {
      scale: scales[seed % scales.length],
      harmonyRatio: harmonyRatios[(seed >> 4) % harmonyRatios.length], // eslint-disable-line no-bitwise
    };
  }

  /**
   * One column per hour. Height and dither density both follow that hour's activity.
   */
  get hours() {
    const playing = this.isPlaying
      ? Math.min(LAST_HOUR, Math.floor(this.playbackProgress * 24))
      : -1;
    const bars = barsFor(
      this.activityByHour.map((value, hour) => ({ value, hour })),
      "value"
    );

    return bars.map((bar) => ({
      ...bar,
      height: trustHTML(`height: ${(bar.share * 100).toFixed(2)}%`),
      isPeak: bar.hour === this.mostActiveHour,
      isPlaying: bar.hour === playing,
      label: bar.hour % 3 === 0 ? this.formatHour(bar.hour) : null,
    }));
  }

  get playButtonText() {
    return i18nForOwner(
      "discourse_rewind.reports.time_of_day_activity.play_button",
      this.args.isOwnRewind,
      { username: this.args.user?.username }
    );
  }

  formatHour(hour) {
    const period = hour >= 12 ? "PM" : "AM";
    const displayHour = hour === 0 ? 12 : hour > 12 ? hour - 12 : hour;
    return `${displayHour}${period}`;
  }

  @action
  stopWaveform() {
    if (this.audioSource) {
      this.audioSource.stop();
    }
    if (this.audioContext) {
      this.audioContext.close();
    }
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame);
    }
    if (this.playbackTimeout) {
      clearTimeout(this.playbackTimeout);
    }
    this.isPlaying = false;
    this.playbackProgress = 0;
    this.audioContext = null;
    this.audioSource = null;
    this.playbackTimeout = null;
    this.stereoPanner = null;
  }

  @action
  async playWaveform() {
    if (this.isPlaying) {
      this.stopWaveform();
      return;
    }

    this.isPlaying = true;
    this.playbackProgress = 0;

    try {
      this.audioContext = new (
        window.AudioContext || window.webkitAudioContext
      )();

      // Musical timing: 24 hours at 200 BPM
      const duration = 7.2; // (24 / 200) * 60 seconds

      const sampleRate = this.audioContext.sampleRate;
      const numSamples = duration * sampleRate;

      const buffer = this.audioContext.createBuffer(1, numSamples, sampleRate);
      const channelData = buffer.getChannelData(0);

      const params = this.personalizedAudioParams;
      const scale = params.scale;
      const activityByHour = this.activityByHour;
      const maxActivity = this.maxActivity;
      const peakHourTime = (this.mostActiveHour / LAST_HOUR) * duration;

      const samplesPerHour = numSamples / 24;

      for (let i = 0; i < numSamples; i++) {
        const activity = activityAt(activityByHour, i / samplesPerHour);

        // Map activity to personalized musical scale
        const normalizedActivity = activity / maxActivity;

        // Map to scale index with smooth interpolation
        const scalePosition = normalizedActivity * (scale.length - 1);
        const lowerIndex = Math.floor(scalePosition);
        const upperIndex = Math.min(lowerIndex + 1, scale.length - 1);
        const blend = scalePosition - lowerIndex;

        let frequency =
          scale[lowerIndex] + (scale[upperIndex] - scale[lowerIndex]) * blend;

        const time = i / sampleRate;

        // Generate main voice and harmony
        const mainWave = triangleWave(frequency, time);
        const harmonyWave = triangleWave(frequency * params.harmonyRatio, time);

        // Mix voices (70/30 split)
        const mixedWave = mainWave * 0.7 + harmonyWave * 0.3;

        // Add bit crushing effect for retro feel
        const crushed =
          Math.round(mixedWave * BIT_CRUSH_STEPS) / BIT_CRUSH_STEPS;

        // Add minimal noise (sparkle at peak hour)
        const isPeakMoment =
          Math.abs(time - peakHourTime) < PEAK_WINDOW && time >= peakHourTime;

        const noise = (Math.random() - 0.5) * (isPeakMoment ? 0.08 : 0.02);

        // Reduce volume for zero/very low activity sections
        const lowActivityVolume = normalizedActivity < 0.05 ? 0.3 : 1;

        // Output with all effects applied
        channelData[i] = (crushed * 0.15 + noise) * lowActivityVolume;
      }

      // Create source and play
      this.audioSource = this.audioContext.createBufferSource();
      this.audioSource.buffer = buffer;

      // Add stereo panner (pan from left to right as time progresses)
      this.stereoPanner = this.audioContext.createStereoPanner();
      this.stereoPanner.pan.value = -1; // Start at left

      // Add filter for retro feel
      const filter = this.audioContext.createBiquadFilter();
      filter.type = "lowpass";
      filter.frequency.value = 2500; // Tame the highs

      // Simple delay for subtle depth
      const delay = this.audioContext.createDelay();
      delay.delayTime.value = 0.15; // 150ms delay

      const delayGain = this.audioContext.createGain();
      delayGain.gain.value = 0.2; // Subtle echo

      // Connect audio graph: source -> filter -> panner + delay feedback
      this.audioSource.connect(filter);
      filter.connect(this.stereoPanner);

      // Add subtle delay feedback
      filter.connect(delay);
      delay.connect(delayGain);
      delayGain.connect(this.stereoPanner);

      this.stereoPanner.connect(this.audioContext.destination);

      this.audioSource.start();

      // Animate playback progress and stereo panning
      const startTime = Date.now();
      const animate = () => {
        const elapsed = (Date.now() - startTime) / 1000;
        this.playbackProgress = Math.min(elapsed / duration, 1);

        // Pan from left (-1) to right (1) as we progress
        if (this.stereoPanner) {
          this.stereoPanner.pan.value = -1 + this.playbackProgress * 2;
        }

        if (this.playbackProgress < 1) {
          this.animationFrame = requestAnimationFrame(animate);
        }
      };
      this.animationFrame = requestAnimationFrame(animate);

      // Reset playing state when done
      this.playbackTimeout = setTimeout(() => {
        this.stopWaveform();
      }, duration * 1000);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Error playing waveform:", error);
      this.stopWaveform();
    }
  }

  <template>
    <div class="rewind-report-page --time-of-day-activity">
      <h2 class="rewind-report-title">{{i18n
          "discourse_rewind.reports.time_of_day_activity.title"
        }}</h2>

      <ol class="rewind-rhythm">
        {{#each this.hours as |hour|}}
          <li
            class={{dConcatClass
              "rewind-rhythm__hour"
              (if hour.isPeak "is-peak")
              (if hour.isPlaying "is-playing")
            }}
          >
            <span
              class="rewind-rhythm__bar"
              data-density={{hour.density}}
              style={{hour.height}}
            ></span>
            {{#if hour.label}}
              <span class="rewind-rhythm__label">{{hour.label}}</span>
            {{/if}}
          </li>
        {{/each}}
      </ol>

      <DButton
        class={{dConcatClass
          "rewind-btn --default rewind-rhythm__play"
          (if this.isPlaying "is-playing")
        }}
        @action={{this.playWaveform}}
        @icon={{if this.isPlaying "volume-xmark" "volume-high"}}
        @translatedTitle={{if
          this.isPlaying
          (i18n "discourse_rewind.reports.time_of_day_activity.stop_button")
          this.playButtonText
        }}
      />
    </div>
  </template>
}
