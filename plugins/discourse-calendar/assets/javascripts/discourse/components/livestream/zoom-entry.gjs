import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { modifier } from "ember-modifier";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import fetchZoomJoinPayload from "../../lib/fetch-zoom-join-payload";
import { loadZoomMeetingSdkEmbedded } from "../../lib/load-zoom-meeting-sdk";

const VIDEO_ASPECT_RATIO = 16 / 9;
const MIN_VIDEO_WIDTH = 240;
const MAX_VIDEO_WIDTH = 1440;
const MIN_VIDEO_HEIGHT = 135;
const MAX_VIDEO_HEIGHT = 810;
const DEFAULT_VIEW_TYPE = "speaker";

function serializeZoomError(error) {
  if (!error) {
    return { message: "Unknown Zoom error" };
  }

  if (typeof error === "string") {
    return { message: error };
  }

  let knownError = false;
  if (error.reason === "Meeting has not started") {
    knownError = true;
  }

  return {
    name: error.name,
    message: error.message,
    type: error.type,
    reason: error.reason,
    errorCode: error.errorCode,
    status: error.status,
    stack: error.stack,
    knownError,
    ...Object.fromEntries(
      Object.entries(error).filter(([, value]) => typeof value !== "function")
    ),
  };
}

export default class LivestreamZoomEntry extends Component {
  @service capabilities;
  @service currentUser;
  @service siteSettings;

  @tracked errorMessage;
  @tracked isJoining = false;
  @tracked isJoined = false;
  @tracked showZoomFrame = false;
  zoomAppRoot = null;
  zoomClient = null;
  zoomMutationObserver = null;
  zoomResizeObserver = null;
  zoomLayoutFrame = null;
  zoomVideoSyncFrame = null;

  registerZoomRoot = modifier((element) => {
    this.zoomAppRoot = element;

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
        this.zoomAppRoot = null;
      }
    };
  });

  willDestroy() {
    super.willDestroy(...arguments);
    this.zoomMutationObserver?.disconnect();
    this.zoomResizeObserver?.disconnect();
    this.zoomClient?.leaveMeeting?.();
    cancelAnimationFrame(this.zoomLayoutFrame);
    cancelAnimationFrame(this.zoomVideoSyncFrame);
  }

  get topic() {
    return this.args.event.post.topic;
  }

  get shouldRender() {
    return (
      this.siteSettings.livestream_zoom_enabled &&
      this.args.event.livestreamChatChannelId &&
      this.currentUser
    );
  }

  get isDesktop() {
    return this.capabilities.viewport.lg;
  }

  get mobileZoomRoute() {
    return getURL(`/t/${this.topic.slug}/${this.topic.id}/zoom`);
  }

  get showFallbackLink() {
    return !isEmpty(this.errorMessage) || !this.currentUser;
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

  @action
  async joinZoom() {
    if (this.isJoining || this.isJoined) {
      return;
    }

    this.errorMessage = null;
    this.isJoining = true;
    this.showZoomFrame = true;

    try {
      const zoomJoinPayload = await fetchZoomJoinPayload(this.topic.id);
      const ZoomMtgEmbedded = await loadZoomMeetingSdkEmbedded();
      this.zoomClient = ZoomMtgEmbedded.createClient();

      if (!this.zoomClientInitialized) {
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
            this.isJoined = false;
            this.showZoomFrame = false;

            // Deletes inline styles that Zoom applies which leaves a big empty box on the page
            this.zoomAppRoot.removeAttribute("style");
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

      this.isJoined = true;
    } catch (err) {
      const serializedError = serializeZoomError(err);
      // eslint-disable-next-line no-console
      console.error("Error joining Zoom meeting", serializedError);

      // No need to show the generic error message if we know that Zoom will
      // show the correct message in certain  known cases.
      if (serializedError.knownError) {
        return;
      }

      this.errorMessage = i18n("discourse_calendar.livestream.zoom.load_error");
    } finally {
      this.zoomLayoutFrame = window.requestAnimationFrame(() =>
        this.syncZoomLayout()
      );
      this.zoomVideoSyncFrame = window.requestAnimationFrame(() =>
        this.syncVideoSize()
      );
      this.isJoining = false;
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
                @disabled={{this.isJoining}}
              />
            {{/unless}}

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
          <DButton
            @route="topic-zoom"
            @routeModels={{array this.topic.slug this.topic.id}}
            @label="discourse_calendar.livestream.zoom.join"
            @icon="video"
            class="btn-primary"
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
