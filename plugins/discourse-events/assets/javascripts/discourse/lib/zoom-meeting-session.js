import { tracked } from "@glimmer/tracking";
import { setOwner } from "@ember/owner";
import { i18n } from "discourse-i18n";
import fetchZoomJoinPayload from "./fetch-zoom-join-payload";
import { loadZoomMeetingSdkEmbedded } from "./load-zoom-meeting-sdk";
import { computeZoomViewSize, syncZoomLayout } from "./zoom-component-view-dom";
import { serializeZoomError } from "./zoom-error";

const DEFAULT_VIEW_TYPE = "speaker";
export const RETRY_DELAY_SECONDS = 30;
export const MAX_RETRY_ATTEMPTS = 40;

// Owns the Zoom embedded SDK client for one livestream entry: joining and
// leaving the meeting, plus the "meeting has not started" retry countdown.
// The component that creates it is purely presentational and reads the
// tracked state here; the modifier attached to the element Zoom renders its
// component view into registers that element via `registerRoot`.
export default class ZoomMeetingSession {
  @tracked errorMessage;
  @tracked isJoining = false;
  @tracked isJoined = false;
  @tracked showZoomFrame = false;
  @tracked retryCountdown = null;
  @tracked isRetryingNow = false;

  element = null;
  retryAttempts = 0;
  retryTimer = null;
  zoomClient = null;
  zoomClientInitialized = false;
  layoutFrame = null;
  videoSyncFrame = null;

  #tornDown = false;

  constructor(owner, { topicId, canJoin, onBeforeJoinAttempt }) {
    setOwner(this, owner);
    this.topicId = topicId;
    this.canJoin = canJoin;
    this.onBeforeJoinAttempt = onBeforeJoinAttempt;
  }

  teardown() {
    this.#tornDown = true;
    clearInterval(this.retryTimer);
    cancelAnimationFrame(this.layoutFrame);
    cancelAnimationFrame(this.videoSyncFrame);
    this.zoomClient?.leaveMeeting?.();
  }

  registerRoot(element) {
    this.element = element;
  }

  unregisterRoot(element) {
    if (this.element === element) {
      this.element = null;
    }
  }

  get isWaitingForStart() {
    return this.retryCountdown !== null;
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

      if (serializedError.meetingNotStarted) {
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
      this.errorMessage = i18n("discourse_calendar.livestream.zoom.load_error");
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

    if (!this.zoomClientInitialized) {
      const ZoomMtgEmbedded = await loadZoomMeetingSdkEmbedded();
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

      this.zoomClientInitialized = true;
    }

    await this.zoomClient.join({
      signature: zoomJoinPayload.signature,
      sdkKey: zoomJoinPayload.sdk_key,
      meetingNumber: zoomJoinPayload.meeting_number,
      password: zoomJoinPayload.password || "",
      userName: zoomJoinPayload.user_name,
      userEmail: zoomJoinPayload.user_email,
    });
  }

  syncVideoSize() {
    if (!this.zoomClient) {
      return;
    }

    this.zoomClient.updateVideoOptions({
      viewSizes: {
        default: computeZoomViewSize(this.element),
      },
    });
  }

  leaveZoom() {
    this.isJoined = false;
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
      this.attemptRejoin();
    }, 1000);
  }

  stopRetrying() {
    clearInterval(this.retryTimer);
    this.retryTimer = null;
    this.retryCountdown = null;
    this.isRetryingNow = false;
    this.retryAttempts = 0;
  }

  // The client is deliberately reused. `ZoomMtgEmbedded.destroyClient()` never
  // unmounts the React root that `join()` mounted into the app root, so a
  // fresh client would call `createRoot()` on a container that already has one
  // and render nothing. Joining again on the same client re-runs the join
  // against the already-mounted component view.
  async attemptRejoin() {
    this.retryCountdown = null;
    this.isRetryingNow = true;

    await this.join();
  }
}
