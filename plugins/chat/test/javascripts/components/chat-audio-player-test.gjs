import {
  blur,
  click,
  find,
  render,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatAudioPlayer from "discourse/plugins/chat/discourse/components/chat-audio-player";

module("Component | ChatAudioPlayer", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    sinon.stub(window.HTMLMediaElement.prototype, "load");
    sinon.stub(window.HTMLMediaElement.prototype, "pause");
    sinon.stub(window.HTMLMediaElement.prototype, "play").resolves();
    this.waveform = Array.from({ length: 40 }, (_, index) => index * 6);
  });

  test("loads the media source after insertion on iOS", async function (assert) {
    sinon
      .stub(this.owner.lookup("service:capabilities"), "isIOS")
      .get(() => true);

    await render(
      <template>
        <ChatAudioPlayer
          @src="/uploads/voice-message.weba"
          @waveform={{this.waveform}}
          @waveformVersion={{1}}
        />
      </template>
    );

    assert.true(
      find(".chat-audio-player__media").load.calledOnce,
      "the source is explicitly loaded"
    );
  });

  test("renders accessible voice-message playback controls", async function (assert) {
    await render(
      <template>
        <ChatAudioPlayer
          @src="/uploads/voice-message.weba"
          @waveform={{this.waveform}}
          @waveformVersion={{1}}
        />
      </template>
    );

    assert.dom(".chat-audio-player").exists("the custom audio player renders");
    assert
      .dom(".chat-audio-player")
      .hasClass("--voice-message", "stored waveforms use voice-note styling");
    assert
      .dom(".chat-audio-player__media")
      .hasAttribute(
        "src",
        "/uploads/voice-message.weba",
        "the audio source is set"
      );
    assert
      .dom(".chat-audio-player__playback")
      .hasClass("btn-primary", "playback is the primary player action");
    assert
      .dom(".chat-audio-player__playback")
      .hasAttribute(
        "aria-label",
        "Play audio",
        "the playback control is named"
      );
    assert
      .dom(".chat-audio-player__seek")
      .hasAttribute(
        "aria-label",
        "Seek through audio",
        "the seek control is named"
      );
    assert
      .dom(
        ".chat-audio-player__waveform-bars:not(.--progress) .chat-audio-player__bar"
      )
      .exists({ count: 40 }, "the seek control has a waveform track");
    assert
      .dom(
        ".chat-audio-player__waveform-bars.--progress .chat-audio-player__bar"
      )
      .exists({ count: 40 }, "the waveform has a playback progress layer");
    assert
      .dom(".chat-audio-player__position")
      .exists("the waveform shows the playback position");
    assert
      .dom(".chat-audio-player__speed")
      .hasText("1×", "the initial playback speed is visible");
    assert
      .dom(".chat-audio-player__more")
      .hasAttribute("aria-label", "More audio actions", "the menu is named");
    assert
      .dom(".chat-audio-player__download")
      .doesNotExist("the secondary action is hidden until requested");

    await click(".chat-audio-player__more");

    assert
      .dom(".chat-audio-player__download")
      .hasAttribute(
        "href",
        "/uploads/voice-message.weba",
        "the download action targets this audio upload"
      );
    assert
      .dom(".chat-audio-player__download")
      .hasAttribute(
        "download",
        "",
        "the action downloads instead of navigating"
      );
  });

  test("updates the elapsed time and duration from media events", async function (assert) {
    await render(
      <template>
        <ChatAudioPlayer
          @src="/uploads/voice-message.weba"
          @waveform={{this.waveform}}
          @waveformVersion={{1}}
        />
      </template>
    );

    const audio = find(".chat-audio-player__media");
    Object.defineProperty(audio, "duration", {
      configurable: true,
      value: 125,
    });
    Object.defineProperty(audio, "currentTime", {
      configurable: true,
      value: 65,
      writable: true,
    });
    await triggerEvent(audio, "durationchange");
    await triggerEvent(audio, "timeupdate");

    assert
      .dom(".chat-audio-player__time")
      .hasText("1:05 / 2:05", "the player formats elapsed and total time");
    assert.strictEqual(
      find(".chat-audio-player__waveform").style.getPropertyValue(
        "--chat-audio-player-progress"
      ),
      "52%",
      "the waveform reflects continuous playback progress"
    );
  });

  test("uses a neutral waveform without stored metadata", async function (assert) {
    await render(
      <template>
        <ChatAudioPlayer @src="/uploads/voice-message.weba" />
      </template>
    );

    assert
      .dom(".chat-audio-player")
      .doesNotHaveClass(
        "--voice-message",
        "ordinary audio keeps attachment styling"
      );
    assert
      .dom(
        ".chat-audio-player__waveform-bars:not(.--progress) .chat-audio-player__bar"
      )
      .exists({ count: 40 }, "ordinary audio uses a stable neutral waveform");
    assert
      .dom(
        ".chat-audio-player__waveform-bars:not(.--progress) .chat-audio-player__bar.--height-8"
      )
      .exists("the fallback waveform has a varied contour");
    assert
      .dom(".chat-audio-player__position")
      .exists("ordinary audio uses the same playback position marker");

    await click(".chat-audio-player__more");

    assert
      .dom(".chat-audio-player__download")
      .hasAttribute(
        "href",
        "/uploads/voice-message.weba",
        "ordinary audio keeps its download action"
      );
  });

  test("uses the stored duration until media metadata loads", async function (assert) {
    await render(
      <template>
        <ChatAudioPlayer
          @durationMs={{125000}}
          @src="/uploads/voice-message.weba"
        />
      </template>
    );

    assert
      .dom(".chat-audio-player__time")
      .hasText("0:00 / 2:05", "the stored duration is shown immediately");
    assert
      .dom(".chat-audio-player__seek")
      .isNotDisabled("the stored duration enables seeking");
    assert.dom(".chat-audio-player__seek").hasAttribute("max", "125");
    assert
      .dom(".chat-audio-player__media")
      .hasAttribute("preload", "none", "stored metadata avoids a media fetch");
  });

  test("preloads metadata when no stored duration is available", async function (assert) {
    await render(
      <template>
        <ChatAudioPlayer @src="/uploads/voice-message.weba" />
      </template>
    );

    assert.dom(".chat-audio-player__media").hasAttribute("preload", "metadata");
  });

  test("falls back for unsupported waveform metadata versions", async function (assert) {
    await render(
      <template>
        <ChatAudioPlayer
          @src="/uploads/voice-message.weba"
          @waveform={{this.waveform}}
          @waveformVersion={{2}}
        />
      </template>
    );

    assert
      .dom(".chat-audio-player")
      .doesNotHaveClass(
        "--voice-message",
        "unknown waveform data does not use voice-note styling"
      );
    assert
      .dom(
        ".chat-audio-player__waveform-bars:not(.--progress) .chat-audio-player__bar"
      )
      .exists({ count: 40 }, "unknown waveform data uses the neutral fallback");
  });

  test("seeks and changes playback speed", async function (assert) {
    await render(
      <template>
        <ChatAudioPlayer @src="/uploads/voice-message.weba" />
      </template>
    );

    const audio = find(".chat-audio-player__media");
    Object.defineProperty(audio, "duration", {
      configurable: true,
      value: 120,
    });
    Object.defineProperty(audio, "currentTime", {
      configurable: true,
      value: 0,
      writable: true,
    });
    await triggerEvent(audio, "durationchange");

    const seek = find(".chat-audio-player__seek");
    seek.value = "30";
    await triggerEvent(seek, "input");

    assert.strictEqual(
      audio.currentTime,
      30,
      "the audio seeks to the selected time"
    );

    await click(".chat-audio-player__speed");

    assert.strictEqual(
      audio.playbackRate,
      1.5,
      "the media playback rate changes"
    );
    assert
      .dom(".chat-audio-player__speed")
      .hasText("1.5×", "the updated speed is visible");
  });

  test("shows the seek focus ring only for keyboard input", async function (assert) {
    await render(
      <template>
        <ChatAudioPlayer
          @durationMs={{10000}}
          @src="/uploads/voice-message.weba"
        />
      </template>
    );

    const seek = find(".chat-audio-player__seek");

    await click(seek);

    assert
      .dom(".chat-audio-player__waveform")
      .doesNotHaveClass(
        "is-keyboard-focused",
        "pointer seeking does not show a focus ring"
      );

    await triggerKeyEvent(seek, "keydown", "ArrowRight");

    assert
      .dom(".chat-audio-player__waveform")
      .hasClass("is-keyboard-focused", "keyboard seeking shows a focus ring");

    await blur(seek);

    assert
      .dom(".chat-audio-player__waveform")
      .doesNotHaveClass(
        "is-keyboard-focused",
        "the focus ring clears when seeking loses focus"
      );
  });

  test("toggles playback and reflects media state", async function (assert) {
    await render(
      <template>
        <ChatAudioPlayer @src="/uploads/voice-message.weba" />
      </template>
    );

    const audio = find(".chat-audio-player__media");

    await click(".chat-audio-player__playback");
    assert.true(audio.play.calledOnce, "the play control starts the audio");

    await triggerEvent(audio, "play");
    assert
      .dom(".chat-audio-player__playback")
      .hasAttribute(
        "aria-label",
        "Pause audio",
        "the control changes to pause"
      );
  });

  test("keeps the controls available when playback start is rejected", async function (assert) {
    await render(
      <template>
        <ChatAudioPlayer @src="/uploads/voice-message.weba" />
      </template>
    );

    find(".chat-audio-player__media").play.rejects(
      new Error("Playback failed")
    );
    await click(".chat-audio-player__playback");

    assert
      .dom(".chat-audio-player__error")
      .doesNotExist("a rejected start does not mark the audio as invalid");
    assert
      .dom(".chat-audio-player__seek")
      .exists("the controls remain available for another attempt");
  });

  test("shows a recoverable error when the media source fails", async function (assert) {
    await render(
      <template>
        <ChatAudioPlayer @src="/uploads/voice-message.weba" />
      </template>
    );

    await triggerEvent(find(".chat-audio-player__media"), "error", {
      bubbles: false,
    });

    assert
      .dom(".chat-audio-player__error")
      .hasText(
        "This audio couldn't be played.",
        "the playback error is explained"
      );
    assert
      .dom(".chat-audio-player__more")
      .exists("the actions menu remains available");

    await click(".chat-audio-player__more");

    assert
      .dom(".chat-audio-player__download")
      .exists("the download fallback remains available");
  });
});
