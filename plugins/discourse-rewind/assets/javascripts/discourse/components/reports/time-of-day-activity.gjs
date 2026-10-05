import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import { i18nForOwner } from "discourse/plugins/discourse-rewind/discourse/lib/rewind-i18n";

const PEAK_WINDOW = 0.2;
const BIT_CRUSH_STEPS = 5;
const LAST_HOUR = 23;
const SVG_WIDTH = 1200;
const SVG_HEIGHT = 200;
const SVG_PADDING = 40;
const PLOT = {
  left: SVG_PADDING,
  right: SVG_WIDTH - SVG_PADDING,
  top: SVG_PADDING,
  bottom: SVG_HEIGHT - SVG_PADDING,
  labelY: SVG_HEIGHT - SVG_PADDING / 2,
  width: SVG_WIDTH - SVG_PADDING * 2,
  height: SVG_HEIGHT - SVG_PADDING * 2,
};

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
  @tracked isGlitching = false;

  audioContext = null;
  audioSource = null;
  playbackTimeout = null;
  stereoPanner = null;
  animationFrame = null;
  hasGlitched = false;

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

  get waveformPath() {
    const points = Array.from({ length: 24 }, (_, hour) => this.pointAt(hour));

    const tension = 0.3;
    let path = `M ${points[0].x} ${points[0].y}`;

    for (let i = 0; i < points.length - 1; i++) {
      const p0 = points[Math.max(i - 1, 0)];
      const p1 = points[i];
      const p2 = points[i + 1];
      const p3 = points[Math.min(i + 2, points.length - 1)];

      const cp1x = p1.x + ((p2.x - p0.x) / 6) * tension;
      const cp1y = p1.y + ((p2.y - p0.y) / 6) * tension;
      const cp2x = p2.x - ((p3.x - p1.x) / 6) * tension;
      const cp2y = p2.y - ((p3.y - p1.y) / 6) * tension;

      path += ` C ${cp1x} ${cp1y}, ${cp2x} ${cp2y}, ${p2.x} ${p2.y}`;
    }

    return path;
  }

  get waveformPoints() {
    return Array.from({ length: 24 }, (_, hour) => {
      const { x, y } = this.pointAt(hour);
      const isActive = hour === this.mostActiveHour;
      return {
        x,
        y,
        hour,
        radius: isActive ? 6 : 2.5,
        class: isActive ? "oscilloscope__dot active" : "oscilloscope__dot",
        showLabel: hour % 3 === 0,
      };
    });
  }

  get gridLines() {
    return Array.from({ length: 5 }, (_, i) => ({
      y: PLOT.top + (i * PLOT.height) / 4,
      style: trustHTML(`opacity: ${i === 0 || i === 4 ? 0.3 : 0.15}`),
    }));
  }

  get playbackPosition() {
    return this.isPlaying
      ? this.pointAt(this.playbackProgress * LAST_HOUR)
      : null;
  }

  get playButtonText() {
    return i18nForOwner(
      "discourse_rewind.reports.time_of_day_activity.play_button",
      this.args.isOwnRewind,
      { username: this.args.user?.username }
    );
  }

  pointAt(fractionalHour) {
    const activity = activityAt(this.activityByHour, fractionalHour);
    return {
      x: PLOT.left + (fractionalHour / LAST_HOUR) * PLOT.width,
      y: PLOT.bottom - (activity / this.maxActivity) * PLOT.height,
    };
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
    this.isGlitching = false;
    this.hasGlitched = false;
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

        // Trigger visual glitch when hitting peak hour
        const peakHourProgress = this.mostActiveHour / LAST_HOUR;
        if (
          !this.hasGlitched &&
          this.playbackProgress >= peakHourProgress &&
          this.playbackProgress < peakHourProgress + 0.05
        ) {
          this.isGlitching = true;
          this.hasGlitched = true;
          setTimeout(() => {
            this.isGlitching = false;
          }, 200);
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
        }}
      </h2>

      <div class="rewind-card">
        <div
          class="time-of-day__oscilloscope
            {{if this.isGlitching '--glitching'}}"
        >
          <DButton
            class="oscilloscope__play-btn {{if this.isPlaying '--playing'}}"
            title={{if
              this.isPlaying
              (i18n "discourse_rewind.reports.time_of_day_activity.stop_button")
              this.playButtonText
            }}
            @action={{this.playWaveform}}
            @icon={{if this.isPlaying "volume-xmark" "volume-high"}}
          />
          <svg
            class="oscilloscope__svg"
            viewBox="0 0 {{SVG_WIDTH}} {{SVG_HEIGHT}}"
          >
            <defs>
              <filter id="glow">
                <feGaussianBlur result="coloredBlur" stdDeviation="2" />
                <feMerge>
                  <feMergeNode in="coloredBlur" />
                  <feMergeNode in="SourceGraphic" />
                </feMerge>
              </filter>
              <filter id="glow-strong">
                <feGaussianBlur result="coloredBlur" stdDeviation="4" />
                <feMerge>
                  <feMergeNode in="coloredBlur" />
                  <feMergeNode in="coloredBlur" />
                  <feMergeNode in="SourceGraphic" />
                </feMerge>
              </filter>
            </defs>

            {{#each this.gridLines as |gridLine|}}
              <line
                class="oscilloscope__grid-line"
                style={{gridLine.style}}
                x1={{PLOT.left}}
                x2={{PLOT.right}}
                y1={{gridLine.y}}
                y2={{gridLine.y}}
              />
            {{/each}}

            {{#each this.waveformPoints as |point|}}
              {{#if point.showLabel}}
                <line
                  class="oscilloscope__grid-line --vertical"
                  x1={{point.x}}
                  x2={{point.x}}
                  y1={{PLOT.top}}
                  y2={{PLOT.bottom}}
                />
                <text
                  class="oscilloscope__time-label"
                  x={{point.x}}
                  y={{PLOT.labelY}}
                >{{this.formatHour point.hour}}</text>
              {{/if}}
            {{/each}}

            <path class="oscilloscope__waveform" d={{this.waveformPath}} />

            {{#each this.waveformPoints as |point|}}
              <circle
                class={{point.class}}
                cx={{point.x}}
                cy={{point.y}}
                r={{point.radius}}
              />
            {{/each}}

            {{#if this.playbackPosition}}
              <circle
                class="oscilloscope__playback-dot"
                cx={{this.playbackPosition.x}}
                cy={{this.playbackPosition.y}}
                r="12"
              />
            {{/if}}
          </svg>
        </div>
      </div>
    </div>
  </template>
}
