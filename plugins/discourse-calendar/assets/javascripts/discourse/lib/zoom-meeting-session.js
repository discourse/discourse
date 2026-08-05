import { tracked } from "@glimmer/tracking";
import { setOwner } from "@ember/owner";
import { next } from "@ember/runloop";
import { isEmpty } from "@ember/utils";
import { i18n } from "discourse-i18n";
import fetchZoomJoinPayload from "./fetch-zoom-join-payload";
import { loadZoomMeetingSdkEmbedded } from "./load-zoom-meeting-sdk";
import { computeZoomViewSize, syncZoomLayout } from "./zoom-component-view-dom";
import { serializeZoomError } from "./zoom-error";

const DEFAULT_VIEW_TYPE = "speaker";
// Scoped per topic: a post stream can render an event card per oneboxed event
// topic, so several sessions share a document and must not consume or clear
// each other's marker.
export function resumeStorageKey(topicId) {
  return `discourse-calendar-zoom-resume:${topicId}`;
}

const RESUME_MAX_AGE_MS = 60_000;
export const RETRY_DELAY_SECONDS = 30;
export const MAX_RETRY_ATTEMPTS = 40;

// Owns the Zoom embedded SDK client for one livestream entry: joining and
// leaving the meeting, plus the "meeting has not started" retry countdown.
// The component that creates it is purely presentational and reads the
// tracked state here; the modifier attached to the element Zoom renders its
// component view into registers that element via `registerRoot`.
//
// Zoom's embedded SDK can only be initialized once per document: after a join
// fails, neither `destroyClient()` nor a fresh container lets it start again,
// and the media layer never re-boots. Zoom's own guidance is to refresh the
// page, so every attempt after the first goes through a reload, carrying the
// countdown state in session storage.
export default class ZoomMeetingSession {
  @tracked errorMessage;
  @tracked isJoining = false;
  @tracked isJoined = false;
  @tracked hasJoinedAudio = false;
  @tracked showZoomFrame = false;
  @tracked retryCountdown = null;
  @tracked isRetryingNow = false;

  element = null;
  retryAttempts = 0;
  retryTimer = null;
  zoomClient = null;
  layoutFrame = null;
  videoSyncFrame = null;
  visibilityListener = null;

  // Never reset: it records that this document has been used, not that a
  // client is currently live.
  sdkInitialized = false;

  // Cleared once the user gives up on being told the webinar started. Carried
  // across the reload, or the next failure would put them back to waiting.
  waitForStartSignal = true;

  #tornDown = false;
  #resumeChecked = false;

  constructor(
    owner,
    { topicId, canJoin, onBeforeJoinAttempt, onJoined, onMeetingNotStarted }
  ) {
    setOwner(this, owner);
    this.topicId = topicId;
    this.canJoin = canJoin;
    this.onBeforeJoinAttempt = onBeforeJoinAttempt;
    this.onJoined = onJoined;
    this.onMeetingNotStarted = onMeetingNotStarted;
  }

  teardown() {
    this.#tornDown = true;
    this.#stopWaitingForVisible();
    clearInterval(this.retryTimer);
    cancelAnimationFrame(this.layoutFrame);
    cancelAnimationFrame(this.videoSyncFrame);
    this.zoomClient?.leaveMeeting?.()?.catch?.(() => {});
  }

  registerRoot(element) {
    this.element = element;

    // `registerRoot` runs from a modifier during render, and the join mutates
    // tracked state the same render already read.
    next(() => {
      if (!this.#tornDown) {
        this.resumeRetry();
      }
    });
  }

  unregisterRoot(element) {
    if (this.element === element) {
      this.element = null;
    }
  }

  get isWaitingForStart() {
    return this.retryCountdown !== null;
  }

  stopWaitingForStart() {
    this.waitForStartSignal = false;
    this.stopRetrying();
  }

  resumeWaitingForStart() {
    this.waitForStartSignal = true;
  }

  async join() {
    if (
      this.isJoining ||
      this.isJoined ||
      this.isWaitingForStart ||
      !this.canJoin()
    ) {
      return;
    }

    if (this.sdkInitialized) {
      this.reloadToRetry();
      return;
    }

    this.errorMessage = null;
    this.isJoining = true;
    this.showZoomFrame = true;

    try {
      // The callback is a convenience (RSVPing the user), not a precondition.
      // A user for whom it fails should still get to watch the webinar.
      await this.onBeforeJoinAttempt?.();
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error("Error marking the user as going", err);
    }

    try {
      await this.performJoin();

      if (this.#tornDown) {
        return;
      }

      this.isJoined = true;
      this.onJoined?.();
      this.stopRetrying();
    } catch (err) {
      const serializedError = serializeZoomError(err);
      // eslint-disable-next-line no-console
      console.error("Error joining Zoom meeting", serializedError);

      // The user navigated away while the join was in flight, so there is
      // nothing left to retry into.
      if (this.#tornDown) {
        return;
      }

      // Once the user has stopped waiting, a failure is just a failure: no
      // countdown, no reload, only the fallback link.
      if (serializedError.meetingNotStarted && this.waitForStartSignal) {
        if (this.onMeetingNotStarted?.()) {
          this.showZoomFrame = false;
          this.element?.removeAttribute("style");
          return;
        }

        this.retryAttempts += 1;

        if (this.retryAttempts <= MAX_RETRY_ATTEMPTS) {
          // The frame stays up so Zoom's own "meeting has not started" panel
          // remains visible alongside the countdown.
          this.isRetryingNow = false;
          this.startRetryCountdown();
          return;
        }
      }

      this.leaveZoom();
      this.errorMessage = i18n(
        serializedError.meetingNotStarted
          ? "discourse_calendar.livestream.zoom.not_started_error"
          : "discourse_calendar.livestream.zoom.load_error"
      );
    } finally {
      this.isJoining = false;

      this.layoutFrame = window.requestAnimationFrame(() =>
        syncZoomLayout(this.element)
      );
      this.videoSyncFrame = window.requestAnimationFrame(() =>
        this.syncVideoSize()
      );
    }
  }

  async performJoin() {
    const zoomJoinPayload = await fetchZoomJoinPayload(this.topicId);

    if (!this.sdkInitialized) {
      const ZoomMtgEmbedded = await loadZoomMeetingSdkEmbedded();
      this.sdkInitialized = true;
      this.zoomClient = ZoomMtgEmbedded.createClient();

      await this.zoomClient.init({
        zoomAppRoot: this.element,
        language: "en-US",
        patchJsMedia: true,
        leaveOnPageUnload: true,
        customize: {
          activeApps: {
            popper: {
              placement: "top",
            },
          },
          video: {
            isResizable: false,
            defaultViewType: DEFAULT_VIEW_TYPE,
            viewSizes: {
              default: computeZoomViewSize(this.element),
            },
            popper: {
              disableDraggable: true,
            },
          },
        },
      });

      this.zoomClient.on("connection-change", (payload) => {
        // Handles the livestream ending while the user is still on the page.
        if (payload.state === "Closed") {
          this.leaveZoom();
        }
      });

      this.zoomClient.on("user-updated", () => this.syncAudioState());
    }

    await this.zoomClient.join({
      signature: zoomJoinPayload.signature,
      sdkKey: zoomJoinPayload.sdk_key,
      meetingNumber: zoomJoinPayload.meeting_number,
      password: zoomJoinPayload.password || "",
      userName: zoomJoinPayload.user_name,
      userEmail: zoomJoinPayload.user_email,
    });

    this.syncAudioState();
  }

  // Joining the meeting does not connect audio: `audio` stays "" until the user
  // picks computer or phone audio in Zoom's own controls. `user-updated` carries
  // only the properties that changed, so the value is re-read from the client
  // rather than taken from the payload.
  syncAudioState() {
    this.hasJoinedAudio = !isEmpty(this.zoomClient?.getCurrentUser?.()?.audio);
  }

  // The SDK only accepts video options once the media session is up. Called
  // any earlier it throws from inside its own bundle, which would take down
  // whatever called it.
  syncVideoSize() {
    if (!this.zoomClient || !this.isJoined) {
      return;
    }

    try {
      this.zoomClient.updateVideoOptions({
        viewSizes: {
          default: computeZoomViewSize(this.element),
        },
      });
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error("Error resizing the Zoom video", serializeZoomError(err));
    }
  }

  leaveZoom() {
    this.isJoined = false;
    this.hasJoinedAudio = false;
    this.showZoomFrame = false;

    // Deletes inline styles that Zoom applies which leaves a big empty box on
    // the page
    this.element?.removeAttribute("style");

    this.stopRetrying();
  }

  startRetryCountdown() {
    clearInterval(this.retryTimer);
    this.retryCountdown = RETRY_DELAY_SECONDS;

    this.retryTimer = setInterval(() => {
      if (this.retryCountdown > 1) {
        this.retryCountdown -= 1;
        return;
      }

      clearInterval(this.retryTimer);
      this.retryTimer = null;
      this.reloadToRetry();
    }, 1000);
  }

  stopRetrying() {
    clearInterval(this.retryTimer);
    this.retryTimer = null;
    this.retryCountdown = null;
    this.isRetryingNow = false;
    this.retryAttempts = 0;
    this.#writeResumeState(null);
  }

  reloadToRetry() {
    this.retryCountdown = null;

    if (!this.canJoin()) {
      this.leaveZoom();
      return;
    }

    this.isRetryingNow = true;

    // Reloading a tab nobody is looking at is pure churn, and attendees who
    // clicked Join early are usually off in another tab.
    if (document.visibilityState === "hidden") {
      this.#reloadWhenVisible();
      return;
    }

    this.#reloadNow();
  }

  reloadPage() {
    window.location.reload();
  }

  // Written immediately before the reload rather than before the wait, so the
  // marker is never stale by the time the far side reads it.
  #reloadNow() {
    this.#writeResumeState({
      topicId: this.topicId,
      attempts: this.retryAttempts,
      at: Date.now(),
    });

    this.reloadPage();
  }

  #reloadWhenVisible() {
    this.visibilityListener = () => {
      if (document.visibilityState !== "visible") {
        return;
      }

      this.#stopWaitingForVisible();

      if (!this.#tornDown) {
        this.#reloadNow();
      }
    };

    document.addEventListener("visibilitychange", this.visibilityListener);
  }

  #stopWaitingForVisible() {
    if (!this.visibilityListener) {
      return;
    }

    document.removeEventListener("visibilitychange", this.visibilityListener);
    this.visibilityListener = null;
  }

  // Picks the countdown back up on the far side of the reload, so the attempt
  // budget survives and a webinar that never starts eventually gives up
  // instead of reloading the page forever.
  resumeRetry() {
    if (this.#resumeChecked) {
      return;
    }

    this.#resumeChecked = true;

    const state = this.#readResumeState();
    this.#writeResumeState(null);

    if (!state || !this.canJoin()) {
      return;
    }

    this.retryAttempts = state.attempts;
    this.join();
  }

  #readResumeState() {
    let raw;

    try {
      raw = window.sessionStorage?.getItem(resumeStorageKey(this.topicId));
    } catch {
      return null;
    }

    if (!raw) {
      return null;
    }

    let state;

    try {
      state = JSON.parse(raw);
    } catch {
      return null;
    }

    if (
      state?.topicId !== this.topicId ||
      !(state.attempts < MAX_RETRY_ATTEMPTS) ||
      !(Date.now() - state.at < RESUME_MAX_AGE_MS)
    ) {
      return null;
    }

    return state;
  }

  #writeResumeState(state) {
    try {
      if (state) {
        window.sessionStorage?.setItem(
          resumeStorageKey(this.topicId),
          JSON.stringify(state)
        );
      } else {
        window.sessionStorage?.removeItem(resumeStorageKey(this.topicId));
      }
    } catch {
      // Session storage can be unavailable; the retry just will not resume.
    }
  }
}
