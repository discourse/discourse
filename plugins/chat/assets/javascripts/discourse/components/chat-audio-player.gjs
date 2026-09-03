import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import { isSupportedAudioWaveform } from "discourse/plugins/chat/discourse/lib/audio-waveform";

const PLAYBACK_RATES = [1, 1.5, 2];
const FALLBACK_WAVEFORM = [
  2, 2, 3, 2, 4, 3, 5, 4, 7, 8, 6, 4, 3, 2, 3, 4, 3, 2, 2, 3, 2, 2, 3, 4, 5, 4,
  3, 2, 3, 4, 3, 2, 4, 3, 2, 3, 2, 2, 3, 2,
];

let activeAudioElement;

export default class ChatAudioPlayer extends Component {
  @service a11y;
  @service capabilities;

  @tracked currentTime = 0;
  @tracked duration = 0;
  @tracked hasError = false;
  @tracked isPlaying = false;
  @tracked isSeekKeyboardFocused = false;
  @tracked playbackRate = PLAYBACK_RATES[0];

  #audioElement;
  #isSeekPointerActive = false;

  willDestroy() {
    super.willDestroy(...arguments);

    if (activeAudioElement === this.#audioElement) {
      activeAudioElement = undefined;
    }

    this.#audioElement?.pause();
  }

  get currentTimeLabel() {
    return this.#formatTime(this.currentTime);
  }

  get durationLabel() {
    return this.#formatTime(this.effectiveDuration);
  }

  get effectiveDuration() {
    if (this.duration > 0) {
      return this.duration;
    }

    const storedDuration = Number(this.args.durationMs) / 1000;
    return Number.isFinite(storedDuration) && storedDuration > 0
      ? storedDuration
      : 0;
  }

  get playbackLabel() {
    return this.isPlaying
      ? i18n("chat.audio_player.pause")
      : i18n("chat.audio_player.play");
  }

  get playbackRateLabel() {
    return i18n("chat.audio_player.playback_rate", {
      rate: this.playbackRate,
    });
  }

  get playbackRateText() {
    return `${this.playbackRate}×`;
  }

  get preload() {
    return Number(this.args.durationMs) > 0 ? "none" : "metadata";
  }

  get playbackProgressStyle() {
    const progress = this.effectiveDuration
      ? Math.min(
          100,
          Math.max(0, (this.currentTime / this.effectiveDuration) * 100)
        )
      : 0;
    return trustHTML(
      `--chat-audio-player-progress: ${progress}%; --chat-audio-player-unplayed: ${100 - progress}%`
    );
  }

  get seekLabel() {
    return i18n("chat.audio_player.seek", {
      current: this.currentTimeLabel,
      duration: this.durationLabel,
    });
  }

  get seekDisabled() {
    return !this.effectiveDuration;
  }

  get seekMaximum() {
    return this.effectiveDuration || 1;
  }

  get hasStoredWaveform() {
    return isSupportedAudioWaveform(
      this.args.waveform,
      this.args.waveformVersion
    );
  }

  get waveformBars() {
    if (!this.hasStoredWaveform) {
      return FALLBACK_WAVEFORM;
    }

    return this.args.waveform.map((value) =>
      Math.max(1, Math.ceil((value / 255) * 8))
    );
  }

  @action
  cyclePlaybackRate() {
    const currentIndex = PLAYBACK_RATES.indexOf(this.playbackRate);
    this.playbackRate =
      PLAYBACK_RATES[(currentIndex + 1) % PLAYBACK_RATES.length];

    if (this.#audioElement) {
      this.#audioElement.playbackRate = this.playbackRate;
    }
  }

  @action
  onDurationChange(event) {
    const duration = event.currentTarget.duration;
    this.duration = Number.isFinite(duration) ? duration : 0;
  }

  @action
  onLoadedMetadata(event) {
    this.onDurationChange(event);
  }

  @action
  onEnded(event) {
    this.isPlaying = false;
    event.currentTarget.currentTime = 0;
    this.currentTime = 0;
  }

  @action
  onError() {
    if (activeAudioElement === this.#audioElement) {
      activeAudioElement = undefined;
    }

    this.hasError = true;
    this.isPlaying = false;
    this.a11y.announce(i18n("chat.audio_player.error"), "assertive");
  }

  @action
  onPause() {
    this.isPlaying = false;
  }

  @action
  onPlay(event) {
    if (activeAudioElement && activeAudioElement !== event.currentTarget) {
      activeAudioElement.pause();
    }

    activeAudioElement = event.currentTarget;
    this.isPlaying = true;
  }

  @action
  onSeek(event) {
    if (!this.#audioElement) {
      return;
    }

    const currentTime = Number(event.currentTarget.value);
    this.#audioElement.currentTime = currentTime;
    this.currentTime = currentTime;
  }

  @action
  onSeekBlur() {
    this.#isSeekPointerActive = false;
    this.isSeekKeyboardFocused = false;
  }

  @action
  onSeekFocus() {
    this.isSeekKeyboardFocused = !this.#isSeekPointerActive;
  }

  @action
  onSeekKeyDown() {
    this.isSeekKeyboardFocused = true;
  }

  @action
  onSeekPointerDown() {
    this.#isSeekPointerActive = true;
    this.isSeekKeyboardFocused = false;
  }

  @action
  onSeekPointerEnd() {
    this.#isSeekPointerActive = false;
  }

  @action
  onTimeUpdate(event) {
    this.currentTime = event.currentTarget.currentTime;
  }

  @action
  setupAudio(element) {
    this.#audioElement = element;
    element.playbackRate = this.playbackRate;

    if (this.capabilities.isSafari || this.capabilities.isIOS) {
      element.load();
    }
  }

  @action
  togglePlayback() {
    if (!this.#audioElement || this.hasError) {
      return;
    }

    if (this.#audioElement.paused) {
      const playPromise = this.#audioElement.play();
      playPromise?.catch(() => {
        this.isPlaying = false;
      });
    } else {
      this.#audioElement.pause();
    }
  }

  #formatTime(seconds) {
    if (!Number.isFinite(seconds) || seconds < 0) {
      return "0:00";
    }

    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = Math.floor(seconds % 60);
    return `${minutes}:${remainingSeconds.toString().padStart(2, "0")}`;
  }

  <template>
    <div
      class={{dConcatClass
        "chat-audio-player"
        (if this.hasStoredWaveform "--voice-message")
      }}
      ...attributes
    >
      <audio
        class="chat-audio-player__media"
        preload={{this.preload}}
        src={{@src}}
        {{didInsert this.setupAudio}}
        {{on "durationchange" this.onDurationChange}}
        {{on "ended" this.onEnded}}
        {{on "error" this.onError}}
        {{on "loadedmetadata" this.onLoadedMetadata}}
        {{on "pause" this.onPause}}
        {{on "play" this.onPlay}}
        {{on "timeupdate" this.onTimeUpdate}}
      ></audio>

      <DButton
        class="btn-primary chat-audio-player__playback"
        @action={{this.togglePlayback}}
        @disabled={{this.hasError}}
        @icon={{if this.isPlaying "pause" "play"}}
        @translatedAriaLabel={{this.playbackLabel}}
        @translatedTitle={{this.playbackLabel}}
      />

      {{#if this.hasError}}
        <span class="chat-audio-player__error">
          {{i18n "chat.audio_player.error"}}
        </span>
      {{else}}
        <div class="chat-audio-player__timeline">
          <div
            class={{dConcatClass
              "chat-audio-player__waveform"
              (if this.isSeekKeyboardFocused "is-keyboard-focused")
            }}
            style={{this.playbackProgressStyle}}
          >
            <div aria-hidden="true" class="chat-audio-player__waveform-bars">
              {{#each this.waveformBars as |height|}}
                <span
                  class={{dConcatClass
                    "chat-audio-player__bar"
                    (concat "--height-" height)
                  }}
                ></span>
              {{/each}}
            </div>
            <div
              aria-hidden="true"
              class="chat-audio-player__waveform-bars --progress"
            >
              {{#each this.waveformBars as |height|}}
                <span
                  class={{dConcatClass
                    "chat-audio-player__bar"
                    "--played"
                    (concat "--height-" height)
                  }}
                ></span>
              {{/each}}
            </div>

            <span aria-hidden="true" class="chat-audio-player__position"></span>

            {{! Pointer-down identifies pointer focus before the focus event fires. }}
            {{! eslint-disable ember/template-no-pointer-down-event-binding }}
            <input
              aria-label={{i18n "chat.audio_player.seek_label"}}
              aria-valuetext={{this.seekLabel}}
              class="chat-audio-player__seek"
              disabled={{this.seekDisabled}}
              max={{this.seekMaximum}}
              min="0"
              step="0.01"
              type="range"
              value={{this.currentTime}}
              {{on "blur" this.onSeekBlur}}
              {{on "focus" this.onSeekFocus}}
              {{on "input" this.onSeek}}
              {{on "keydown" this.onSeekKeyDown}}
              {{on "mousedown" this.onSeekPointerDown}}
              {{on "mouseup" this.onSeekPointerEnd}}
              {{on "pointercancel" this.onSeekPointerEnd}}
              {{on "pointerdown" this.onSeekPointerDown}}
              {{on "pointerup" this.onSeekPointerEnd}}
            />
          </div>
          <span class="chat-audio-player__time">
            <span>{{this.currentTimeLabel}}</span>
            <span aria-hidden="true">/</span>
            <span>{{this.durationLabel}}</span>
          </span>
        </div>
      {{/if}}

      <DButton
        class="btn-transparent chat-audio-player__speed"
        @action={{this.cyclePlaybackRate}}
        @disabled={{this.hasError}}
        @translatedAriaLabel={{this.playbackRateLabel}}
        @translatedLabel={{this.playbackRateText}}
        @translatedTitle={{this.playbackRateLabel}}
      />

      <DMenu
        @ariaLabel={{i18n "chat.audio_player.more_actions"}}
        @icon="ellipsis-vertical"
        @identifier="chat-audio-player-menu"
        @placement="top-end"
        @title={{i18n "chat.audio_player.more_actions"}}
        @triggerClass="btn-transparent chat-audio-player__more"
      >
        <:content as |menu|>
          <DDropdownMenu as |dropdown|>
            <dropdown.item>
              <DButton
                class="btn-transparent chat-audio-player__download"
                download
                {{on "click" menu.close}}
                @href={{@src}}
                @icon="download"
                @translatedLabel={{i18n "chat.audio_player.download"}}
              />
            </dropdown.item>
          </DDropdownMenu>
        </:content>
      </DMenu>
    </div>
  </template>
}
