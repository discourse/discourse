import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { modifier } from "ember-modifier";
import { bind } from "discourse/lib/decorators";
import { loadZoomMeetingSdkEmbedded } from "discourse/lib/load-zoom-meeting-sdk";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import fetchZoomJoinPayload from "../../lib/fetch-zoom-join-payload";

const VIDEO_ASPECT_RATIO = 16 / 9;
const MIN_VIDEO_WIDTH = 240;
const MAX_VIDEO_WIDTH = 1440;
const MIN_VIDEO_HEIGHT = 135;
const MAX_VIDEO_HEIGHT = 810;
const DEFAULT_VIEW_TYPE = "speaker";
const MEETING_NOT_STARTED_ERROR_CODE = 3008;
export const RETRY_DELAY_SECONDS = 30;
export const MAX_RETRY_ATTEMPTS = 40;

function serializeZoomError(error) {
  if (!error) {
    return { message: "Unknown Zoom error" };
  }

  if (typeof error === "string") {
    return { message: error };
  }

  // The reason string is what the SDK returns today, the code is the stable
  // identifier.
  const meetingNotStarted =
    error.reason === "Meeting has not started" ||
    error.errorCode === MEETING_NOT_STARTED_ERROR_CODE;

  return {
    name: error.name,
    message: error.message,
    type: error.type,
    reason: error.reason,
    errorCode: error.errorCode,
    status: error.status,
    stack: error.stack,
    meetingNotStarted,
    ...Object.fromEntries(
      Object.entries(error).filter(([, value]) => typeof value !== "function")
    ),
  };
}

export default class LivestreamZoomEntry extends Component {
  @service appEvents;
  @service capabilities;
  @service currentUser;
  @service discoursePostEventApi;
  @service siteSettings;

  @tracked errorMessage;
  @tracked isJoining = false;
  @tracked isJoined = false;
  @tracked showZoomFrame = false;
  @tracked retryCountdown = null;
  @tracked isRetryingNow = false;
  retryAttempts = 0;
  retryTimer = null;
  zoomAppRoot = null;
  zoomClient = null;
  zoomClientInitialized = false;
  zoomMutationObserver = null;
  zoomResizeObserver = null;
  zoomLayoutFrame = null;
  zoomVideoSyncFrame = null;

  registerZoomRoot = modifier((element) => {
    this.zoomAppRoot = element;

    this.zoomAppRoot.addEventListener("click", this.onZoomLeaveButtonClick, {
      capture: true,
    });

    if (this.capabilities.viewport.lg && window.ResizeObserver) {
      this.zoomResizeObserver?.disconnect();
      this.zoomResizeObserver = new ResizeObserver(() => {
        this.syncVideoSize();
        this.syncZoomLayout();
      });
      this.zoomResizeObserver.observe(element);
    }

    if (window.MutationObserver) {
      this.zoomMutationObserver?.disconnect();
      this.zoomMutationObserver = new MutationObserver(() => {
        this.syncZoomLayout();
      });
      this.zoomMutationObserver.observe(element, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ["style", "class"],
      });
    }

    this.syncZoomLayout();

    return () => {
      this.zoomMutationObserver?.disconnect();
      this.zoomMutationObserver = null;
      this.zoomResizeObserver?.disconnect();
      this.zoomResizeObserver = null;

      if (this.zoomAppRoot === element) {
        this.zoomAppRoot.removeEventListener(
          "click",
          this.onZoomLeaveButtonClick,
          { capture: true }
        );
        this.zoomAppRoot = null;
      }
    };
  });

  willDestroy() {
    super.willDestroy(...arguments);
    this.zoomMutationObserver?.disconnect();
    this.zoomResizeObserver?.disconnect();
    this.zoomClient?.leaveMeeting?.();
    clearInterval(this.retryTimer);
    cancelAnimationFrame(this.zoomLayoutFrame);
    cancelAnimationFrame(this.zoomVideoSyncFrame);
  }

  // Zoom's "meeting has not started" panel has its own leave button, and unlike
  // every other leave path it fires no `connection-change` event: the SDK only
  // reports `Closed` once it has a meeting id, which a join that failed before
  // the host started never gets. Watching the click is the only signal.
  @bind
  onZoomLeaveButtonClick(event) {
    // The joined toolbar's leave button carries the same title, but clicking it
    // only opens Zoom's confirmation popper. Hiding the frame there would
    // strand the user in a meeting they can no longer see or leave. That path
    // reports `Closed` on its own once the user confirms.
    if (this.isJoined) {
      return;
    }

    // `title` is Zoom's translated `toolbar_leave` string, stable only because
    // `performJoin` pins the widget to en-US. The button carries no other
    // distinguishing attribute.
    //
    // This is flaky if the Zoom SDK changes, but it's unavoidable because they
    // don't provide proper hooks for this.
    if (event.target.closest("button.zoom-MuiButton-root")?.title === "Leave") {
      this.leaveZoom();
    }
  }

  get topic() {
    return this.args.event.post.topic;
  }

  get shouldRender() {
    return (
      this.siteSettings.livestream_zoom_enabled &&
      this.currentUser &&
      this.args.event.livestreamChatChannelId &&
      !this.args.event.pastEventTimeframe
    );
  }

  get canJoinNow() {
    return (
      this.args.event.currentlyWithinEventTimeframe ||
      // TODO (martin) showzoom is for testing only, remove before merge
      new URLSearchParams(window.location.search).get("showzoom")
    );
  }

  get isDesktop() {
    return this.capabilities.viewport.lg;
  }

  get showFallbackLink() {
    return !isEmpty(this.errorMessage);
  }

  get isWaitingForStart() {
    return this.retryCountdown !== null;
  }

  get joinDisabled() {
    return this.isJoining || this.isWaitingForStart || !this.canJoinNow;
  }

  get zoomViewSize() {
    const width = Math.max(
      MIN_VIDEO_WIDTH,
      Math.min(
        MAX_VIDEO_WIDTH,
        Math.floor(this.zoomAppRoot?.getBoundingClientRect().width || 0)
      )
    );

    const height = Math.max(
      MIN_VIDEO_HEIGHT,
      Math.min(MAX_VIDEO_HEIGHT, Math.floor(width / VIDEO_ASPECT_RATIO))
    );

    return { width, height };
  }

  syncVideoSize() {
    if (!this.zoomClient) {
      return;
    }

    this.zoomClient.updateVideoOptions({
      viewSizes: {
        default: this.zoomViewSize,
      },
    });
  }

  setInlineStyleValue(element, property, value) {
    if (!element || element.style[property] === value) {
      return;
    }

    element.style[property] = value;
  }

  setInlineHeight(element, height) {
    this.setInlineStyleValue(element, "height", `${height}px`);
  }

  syncZoomLayout() {
    if (!this.zoomAppRoot) {
      return;
    }

    const widget = this.zoomAppRoot.querySelector(
      '[role="region"][aria-label="Zoom Web SDK Widget"]'
    );
    const widgetHeight = Math.ceil(widget?.getBoundingClientRect().height || 0);

    if (widgetHeight > 0) {
      this.setInlineHeight(this.zoomAppRoot, widgetHeight);
    }

    const playerContainers = this.zoomAppRoot.querySelectorAll(
      "video-player-container"
    );
    const galleryPanel = this.zoomAppRoot.querySelector(
      '[id^="suspension-view-tabpanel-gallery"]'
    );

    if (!galleryPanel || playerContainers.length !== 1) {
      return;
    }

    const player = playerContainers[0];
    const playerWrapper = player.parentElement;
    const gridWrapper = playerWrapper?.parentElement;
    const innerPaper = galleryPanel.parentElement;
    const outerPaper = innerPaper?.parentElement;
    const resizable = outerPaper?.parentElement;
    const absoluteBox = resizable?.parentElement;
    const toolbar = innerPaper?.querySelector(".zoom-MuiToolbar-root");
    const footer = Array.from(outerPaper?.children || []).find(
      (element) => element !== innerPaper
    );

    const playerHeight = Math.ceil(player.getBoundingClientRect().height || 0);
    const toolbarHeight = Math.ceil(
      toolbar?.getBoundingClientRect().height || 0
    );
    const footerHeight = Math.ceil(footer?.getBoundingClientRect().height || 0);
    const innerHeight = toolbarHeight + playerHeight;
    const outerHeight = innerHeight + footerHeight + 4;

    if (!playerHeight || !innerHeight || !outerHeight) {
      return;
    }

    // Zoom's component view currently centers a single tile inside the
    // gallery-limited panel. Collapse that wrapper so the lone presenter tile
    // sits directly below the toolbar instead of midway down the widget.
    this.setInlineStyleValue(player, "top", "0px");
    this.setInlineStyleValue(player, "bottom", "auto");

    [playerWrapper, gridWrapper, galleryPanel].forEach((element) => {
      this.setInlineHeight(element, playerHeight);
    });

    this.setInlineHeight(innerPaper, innerHeight);
    [outerPaper, resizable, absoluteBox, this.zoomAppRoot].forEach(
      (element) => {
        this.setInlineHeight(element, outerHeight);
      }
    );
  }

  // Attendance is what follows a user into the livestream chat channel, so
  // someone who joins the webinar without ever answering the RSVP would sit in
  // front of a read-only chat. Anyone who has already made a choice, including
  // an explicit "not going", keeps it.
  async markAsGoing() {
    const event = this.args.event;

    if (!event.canUpdateAttendance || event.watchingInvitee?.status) {
      return;
    }

    const payload = { status: "going" };
    const appEventData = { status: payload.status, postId: event.id };

    if (event.watchingInvitee) {
      await this.discoursePostEventApi.updateEventAttendance(event, payload);
      this.appEvents.trigger("calendar:update-invitee-status", appEventData);
    } else {
      await this.discoursePostEventApi.joinEvent(event, payload);
      this.appEvents.trigger("calendar:create-invitee-status", appEventData);
    }
  }

  async performJoin() {
    const zoomJoinPayload = await fetchZoomJoinPayload(this.topic.id);

    if (!this.zoomClientInitialized) {
      const ZoomMtgEmbedded = await loadZoomMeetingSdkEmbedded();
      this.zoomClient = ZoomMtgEmbedded.createClient();

      await this.zoomClient.init({
        zoomAppRoot: this.zoomAppRoot,
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
              default: this.zoomViewSize,
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

  hideZoomFrame() {
    this.showZoomFrame = false;

    // Deletes inline styles that Zoom applies which leaves a big empty box on the page
    this.zoomAppRoot?.removeAttribute("style");
  }

  leaveZoom() {
    this.isJoined = false;
    this.hideZoomFrame();
    this.stopRetrying();
  }

  // The client is deliberately reused. `ZoomMtgEmbedded.destroyClient()` never
  // unmounts the React root that `join()` mounted into `zoomAppRoot`, so a
  // fresh client would call `createRoot()` on a container that already has one
  // and render nothing. Joining again on the same client re-runs the join
  // against the already-mounted widget.
  async attemptRejoin() {
    this.retryCountdown = null;
    this.isRetryingNow = true;

    await this.joinZoom();
  }

  @action
  async joinZoom() {
    if (
      this.isJoining ||
      this.isJoined ||
      this.isWaitingForStart ||
      !this.canJoinNow
    ) {
      return;
    }

    this.errorMessage = null;
    this.isJoining = true;
    this.showZoomFrame = true;

    try {
      await this.markAsGoing();
    } catch (err) {
      // RSVPing is a convenience, not a precondition. A user who cannot be
      // marked as going should still get to watch the webinar.
      // eslint-disable-next-line no-console
      console.error("Error marking the user as going", err);
    }

    try {
      await this.performJoin();

      if (this.isDestroying || this.isDestroyed) {
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
      if (this.isDestroying || this.isDestroyed) {
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

      this.zoomLayoutFrame = window.requestAnimationFrame(() =>
        this.syncZoomLayout()
      );
      this.zoomVideoSyncFrame = window.requestAnimationFrame(() =>
        this.syncVideoSize()
      );
    }
  }

  <template>
    {{#if this.shouldRender}}
      <div class="discourse-calendar-livestream-zoom-entry">
        {{#if this.isDesktop}}
          <div class="discourse-calendar-livestream-zoom-entry__actions">
            {{#unless this.isJoined}}
              <DButton
                @action={{this.joinZoom}}
                @label="discourse_calendar.livestream.zoom.join"
                @icon="video"
                class="btn-primary"
                @disabled={{this.joinDisabled}}
              />
            {{/unless}}

            {{#unless this.canJoinNow}}
              <p class="discourse-calendar-livestream-zoom-entry__waiting">
                {{i18n "discourse_calendar.livestream.zoom.too_early"}}
              </p>
            {{/unless}}

            {{#if this.isWaitingForStart}}
              <p class="discourse-calendar-livestream-zoom-entry__waiting">
                {{i18n
                  "discourse_calendar.livestream.zoom.not_started_retrying"
                  count=this.retryCountdown
                }}
              </p>
            {{else if this.isRetryingNow}}
              <p class="discourse-calendar-livestream-zoom-entry__waiting">
                {{i18n
                  "discourse_calendar.livestream.zoom.not_started_trying_again"
                }}
              </p>
            {{/if}}

            {{#if this.errorMessage}}
              <p class="discourse-calendar-livestream-zoom-entry__error">
                {{this.errorMessage}}
              </p>
            {{/if}}

            {{#if this.showFallbackLink}}
              <DButton
                @href={{@event.livestreamUrl}}
                @label="discourse_calendar.livestream.zoom.open_in_zoom"
                @icon="up-right-from-square"
              />
            {{/if}}
          </div>

          <div
            class={{dConcatClass
              "discourse-calendar-livestream-zoom-entry__frame"
              (if this.showZoomFrame "--visible")
              (if this.isJoined "--joined")
            }}
            {{this.registerZoomRoot}}
          ></div>
        {{else}}
          <div class="discourse-calendar-livestream-zoom-entry__actions">
            <DButton
              @route="topic-zoom"
              @routeModels={{array this.topic.slug this.topic.id}}
              @label="discourse_calendar.livestream.zoom.join"
              @icon="video"
              class="btn-primary"
              @disabled={{this.joinDisabled}}
            />

            {{#unless this.canJoinNow}}
              <p class="discourse-calendar-livestream-zoom-entry__waiting">
                {{i18n "discourse_calendar.livestream.zoom.too_early"}}
              </p>
            {{/unless}}
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
