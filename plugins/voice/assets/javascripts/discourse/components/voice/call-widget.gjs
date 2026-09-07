import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DMenu from "discourse/float-kit/components/d-menu";
import { avatarUrl } from "discourse/lib/avatar-utils";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import { activeRingingEntries } from "../../lib/voice/ringing";
import {
  computeWidgetGrid,
  trackGridSize,
} from "../../lib/voice/video-grid-layout";
import VoiceInviteUsersModal from "../modal/voice-invite-users";
import VoiceRoomInfoModal from "../modal/voice-room-info";
import VoiceCallControls from "./call-controls";
import VoiceRecordingBadge from "./recording-badge";
import VoiceRingingTile from "./ringing-tile";
import VoiceTranscriptBadge from "./transcript-badge";
import VoiceVideoTile from "./video-tile";

const WIDGET_VIDEO_TILE_BUDGET = 4;
const WIDGET_VIEWPORT_MARGIN = 16;
const WIDGET_MIN_WIDTH = 300;
const WIDGET_MIN_HEIGHT = 180;
const WIDGET_EXTRA_MINIMIZED_WIDTH = 118;
const WIDGET_EXTRA_MINIMIZED_HEIGHT = 52;
const WIDGET_MAX_WIDTH_RATIO = 0.5;
const WIDGET_MAX_HEIGHT_RATIO = 0.5;
const WIDGET_SIZE_KEY = "voice-widget-size";
const DRAG_THRESHOLD = 3;
const RESIZE_CORNERS = ["nw", "ne", "sw", "se"];

function clamp(value, min, max) {
  if (max < min) {
    return min;
  }
  return Math.min(Math.max(value, min), max);
}

export default class VoiceCallWidget extends Component {
  @service capabilities;
  @service currentUser;
  @service modal;
  @service router;
  @service voiceRooms;
  @service voiceWebrtc;
  @service keyValueStore;

  @tracked widgetWidth = null;
  @tracked widgetHeight = null;
  @tracked posLeft = null;
  @tracked posTop = null;
  @tracked dragging = false;
  @tracked resizing = false;
  @tracked extraMinimized = false;
  @tracked tileAreaWidth = 0;
  @tracked tileAreaHeight = 0;
  @tracked tileAreaGap = 0;

  // Ring windows expire by wall clock, which nothing tracked observes — a
  // coarse ticker re-evaluates them so "Calling…" tiles disappear on time.
  @tracked ringingClock = Date.now();

  resizeCorners = RESIZE_CORNERS;

  widgetElement = null;
  dragState = null;
  resizeState = null;
  #ringingTicker = null;

  constructor() {
    super(...arguments);
    this.#loadSize();

    // The widget is always mounted, so the tick only touches tracked state
    // while an ephemeral call could actually be showing ringing tiles.
    this.#ringingTicker = setInterval(() => {
      if (this.room?.ephemeral) {
        this.ringingClock = Date.now();
      }
    }, 5000);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    clearInterval(this.#ringingTicker);
    this.#removeResizeListeners();
    this.#removeDragListeners();
    window.clearTimeout(this.dragHoldTimer);
    this.stopWatchingWidgetRoom();
  }

  #loadSize() {
    const raw = this.keyValueStore.get(WIDGET_SIZE_KEY);
    if (!raw) {
      return;
    }
    try {
      const { width, height, extraMinimized } = JSON.parse(raw);
      this.extraMinimized = !!extraMinimized;
      this.widgetWidth = this.extraMinimized ? null : this.#clampWidth(width);
      this.widgetHeight = this.extraMinimized
        ? null
        : this.#clampHeight(height);
    } catch {
      this.widgetWidth = null;
      this.widgetHeight = null;
      this.extraMinimized = false;
    }
  }

  #saveSize() {
    this.keyValueStore.set({
      key: WIDGET_SIZE_KEY,
      value: JSON.stringify({
        width: this.widgetWidth,
        height: this.widgetHeight,
        extraMinimized: this.extraMinimized,
      }),
    });
  }

  #clampWidth(width) {
    if (!width) {
      return null;
    }
    return clamp(
      width,
      WIDGET_MIN_WIDTH,
      Math.min(
        window.innerWidth * WIDGET_MAX_WIDTH_RATIO,
        window.innerWidth - WIDGET_VIEWPORT_MARGIN * 2
      )
    );
  }

  #clampHeight(height) {
    if (!height) {
      return null;
    }
    return clamp(
      height,
      WIDGET_MIN_HEIGHT,
      Math.min(
        window.innerHeight * WIDGET_MAX_HEIGHT_RATIO,
        window.innerHeight - WIDGET_VIEWPORT_MARGIN * 2
      )
    );
  }

  get room() {
    const activeRoomId = this.voiceWebrtc.activeRoomId;
    if (!activeRoomId) {
      return null;
    }

    return (
      this.voiceRooms.rooms.find(
        (room) => Number(room.id) === Number(activeRoomId)
      ) ?? this.voiceWebrtc.activeRoom
    );
  }

  get shouldRender() {
    return (
      !!this.room &&
      !this.onActiveRoomPage &&
      !this.voiceWebrtc.callWidgetHidden
    );
  }

  get onActiveRoomPage() {
    const currentRoute = this.router.currentRoute;
    return (
      currentRoute?.name === "voice-room" &&
      currentRoute?.params?.slug === this.room?.slug
    );
  }

  get participants() {
    return this.room?.active_participants || [];
  }

  get ringingEntries() {
    return activeRingingEntries(this.room, this.ringingClock);
  }

  get grid() {
    return computeWidgetGrid({
      width: this.tileAreaWidth,
      height: this.tileAreaHeight,
      // Ringing pseudo-tiles occupy grid cells like everyone else so tile
      // sizing accounts for them.
      count: this.participants.length + this.ringingEntries.length,
      gap: this.tileAreaGap,
    });
  }

  // Screen shares beat cameras beat everything else for the scarce widget
  // slots. Selection only — render order stays the roster's canonical order,
  // so tiles don't reshuffle when someone toggles a camera; a promoted
  // participant swaps in where the roster places them.
  @cached
  get visibleParticipants() {
    const participants = this.participants;
    // Ringing pseudo-tiles always render, so they claim their share of the
    // grid's slots before participants are picked for the rest.
    const shown = Math.max(
      0,
      (this.grid?.shown ?? participants.length + this.ringingEntries.length) -
        this.ringingEntries.length
    );
    if (shown >= participants.length) {
      return participants;
    }

    const prioritized = [...participants].sort(
      (a, b) => this.#tileRank(a) - this.#tileRank(b)
    );
    const visibleIds = new Set(
      prioritized.slice(0, shown).map((participant) => participant.id)
    );
    return participants.filter((participant) => visibleIds.has(participant.id));
  }

  get hiddenParticipants() {
    const visibleIds = new Set(
      this.visibleParticipants.map((participant) => participant.id)
    );
    return this.participants.filter(
      (participant) => !visibleIds.has(participant.id)
    );
  }

  #tileRank(participant) {
    if (participant.id === this.currentUser?.id) {
      const kind = this.voiceWebrtc.localVideoKind;
      return kind === "screen" ? 0 : kind ? 1 : 2;
    }
    if (participant.is_screen_sharing) {
      return 0;
    }
    return participant.is_video_on ? 1 : 2;
  }

  #isPublishing(participant) {
    if (participant.id === this.currentUser?.id) {
      return !!this.voiceWebrtc.localVideoKind;
    }
    return participant.is_video_on || participant.is_screen_sharing;
  }

  get tiles() {
    const visible = this.visibleParticipants;

    // The live-video budget follows the same priority as slot selection, so a
    // screen share is never demoted to an avatar by roster-earlier cameras.
    const budgeted = new Set(
      [...visible]
        .sort((a, b) => this.#tileRank(a) - this.#tileRank(b))
        .filter((participant) => this.#isPublishing(participant))
        .slice(0, WIDGET_VIDEO_TILE_BUDGET)
        .map((participant) => participant.id)
    );

    return visible.map((participant) => ({
      participant,
      isSelf: participant.id === this.currentUser?.id,
      showVideo: budgeted.has(participant.id),
    }));
  }

  get overflowCount() {
    return this.hiddenParticipants.length;
  }

  get overflowAvatars() {
    return this.hiddenParticipants.slice(0, 3).map((participant) => ({
      id: participant.id,
      src: avatarUrl(participant.avatar_template, "small"),
    }));
  }

  get overflowTitle() {
    return i18n("voice.widget.overflow_tile", { count: this.overflowCount });
  }

  get overflowLabel() {
    return i18n("voice.widget.overflow_count", { count: this.overflowCount });
  }

  get tilesStyle() {
    const grid = this.grid;
    if (!grid) {
      return null;
    }
    return trustHTML(
      `--voice-tile-width: ${grid.tileWidth}px; --voice-tile-height: ${grid.tileHeight}px;`
    );
  }

  get openRoomTitle() {
    return i18n("voice.room.open_page");
  }

  get chatAvailable() {
    return !!this.room?.chat_available;
  }

  get chatTitle() {
    return i18n("voice.widget.open_chat");
  }

  get expandWidgetTitle() {
    return i18n("voice.widget.expand");
  }

  get widgetStyle() {
    const parts = [];

    if (this.capabilities.touch) {
      if (this.posTop !== null) {
        const h = this.widgetElement?.offsetHeight ?? 0;
        const top = clamp(
          this.posTop,
          WIDGET_VIEWPORT_MARGIN,
          Math.max(
            WIDGET_VIEWPORT_MARGIN,
            window.innerHeight - h - WIDGET_VIEWPORT_MARGIN
          )
        );
        parts.push(`inset-block-start: ${top}px;`, "inset-block-end: auto;");
      }
      return parts.length ? trustHTML(parts.join(" ")) : null;
    }

    const width = this.extraMinimized
      ? WIDGET_EXTRA_MINIMIZED_WIDTH
      : this.#clampWidth(this.widgetWidth);
    const height = this.extraMinimized
      ? WIDGET_EXTRA_MINIMIZED_HEIGHT
      : this.#clampHeight(this.widgetHeight);

    if (width) {
      parts.push(`width: ${width}px;`);
    }
    if (height) {
      parts.push(`height: ${height}px; max-height: ${height}px;`);
    }

    if (this.posLeft !== null && this.posTop !== null) {
      const w = width ?? this.widgetElement?.offsetWidth ?? 0;
      const h = height ?? this.widgetElement?.offsetHeight ?? 0;
      const left = clamp(
        this.posLeft,
        WIDGET_VIEWPORT_MARGIN,
        Math.max(
          WIDGET_VIEWPORT_MARGIN,
          window.innerWidth - w - WIDGET_VIEWPORT_MARGIN
        )
      );
      const top = clamp(
        this.posTop,
        WIDGET_VIEWPORT_MARGIN,
        Math.max(
          WIDGET_VIEWPORT_MARGIN,
          window.innerHeight - h - WIDGET_VIEWPORT_MARGIN
        )
      );
      parts.push(
        `inset-inline-start: ${left}px;`,
        "inset-inline-end: auto;",
        `inset-block-start: ${top}px;`,
        "inset-block-end: auto;"
      );
    }

    return parts.length ? trustHTML(parts.join(" ")) : null;
  }

  @action
  openRoom() {
    if (this.room?.slug) {
      this.router.transitionTo("voice-room", this.room.slug);
    }
  }

  @action
  startDrag(event) {
    if (event.type === "mousedown" && event.button !== 0) {
      return;
    }
    if (!this.widgetElement) {
      return;
    }

    const point = this.#eventPoint(event);
    if (!point) {
      return;
    }

    const rect = this.widgetElement.getBoundingClientRect();
    this.dragState = {
      startX: point.x,
      startY: point.y,
      originLeft: rect.left,
      originTop: rect.top,
      width: rect.width,
      height: rect.height,
      armed: false,
    };

    window.addEventListener("mousemove", this.dragWidget);
    window.addEventListener("touchmove", this.dragWidget, { passive: false });
    window.addEventListener("mouseup", this.stopDrag);
    window.addEventListener("touchend", this.stopDrag);

    if (event.cancelable) {
      event.preventDefault();
    }
  }

  @action
  dragWidget(event) {
    const state = this.dragState;
    if (!state) {
      return;
    }

    const point = this.#eventPoint(event);
    if (!point) {
      return;
    }

    const dx = point.x - state.startX;
    const dy = point.y - state.startY;

    if (!state.armed) {
      if (Math.max(Math.abs(dx), Math.abs(dy)) < DRAG_THRESHOLD) {
        return;
      }
      state.armed = true;
      this.dragging = true;
    }

    if (event.cancelable) {
      event.preventDefault();
    }

    this.posTop = clamp(
      state.originTop + dy,
      WIDGET_VIEWPORT_MARGIN,
      window.innerHeight - state.height - WIDGET_VIEWPORT_MARGIN
    );

    if (!this.capabilities.touch) {
      this.posLeft = clamp(
        state.originLeft + dx,
        WIDGET_VIEWPORT_MARGIN,
        window.innerWidth - state.width - WIDGET_VIEWPORT_MARGIN
      );
    }
  }

  @action
  stopDrag() {
    this.#removeDragListeners();
    this.dragState = null;
    this.dragging = false;
  }

  @action
  startResize(corner, event) {
    if (event.type === "mousedown" && event.button !== 0) {
      return;
    }
    if (!this.widgetElement) {
      return;
    }

    const rect = this.widgetElement.getBoundingClientRect();
    const onLeft = corner === "nw" || corner === "sw";
    const onTop = corner === "nw" || corner === "ne";

    this.resizeState = {
      onLeft,
      onTop,
      anchorX: onLeft ? rect.right : rect.left,
      anchorY: onTop ? rect.bottom : rect.top,
    };
    this.resizing = true;

    window.addEventListener("mousemove", this.resizeWidget);
    window.addEventListener("touchmove", this.resizeWidget, { passive: false });
    window.addEventListener("mouseup", this.stopResize);
    window.addEventListener("touchend", this.stopResize);

    if (event.cancelable) {
      event.preventDefault();
    }
    event.stopPropagation();
  }

  @action
  resizeWidget(event) {
    const state = this.resizeState;
    if (!state) {
      return;
    }

    const point = this.#eventPoint(event);
    if (!point) {
      return;
    }

    const maxWidth = Math.min(
      window.innerWidth * WIDGET_MAX_WIDTH_RATIO,
      state.onLeft
        ? state.anchorX - WIDGET_VIEWPORT_MARGIN
        : window.innerWidth - state.anchorX - WIDGET_VIEWPORT_MARGIN
    );
    const maxHeight = Math.min(
      window.innerHeight * WIDGET_MAX_HEIGHT_RATIO,
      state.onTop
        ? state.anchorY - WIDGET_VIEWPORT_MARGIN
        : window.innerHeight - state.anchorY - WIDGET_VIEWPORT_MARGIN
    );

    const rawWidth = Math.abs(point.x - state.anchorX);
    const rawHeight = Math.abs(point.y - state.anchorY);

    if (rawWidth < WIDGET_MIN_WIDTH || rawHeight < WIDGET_MIN_HEIGHT) {
      this.extraMinimized = true;
      this.widgetWidth = null;
      this.widgetHeight = null;
      this.posLeft = null;
      this.posTop = null;

      if (event.cancelable) {
        event.preventDefault();
      }
      return;
    }

    const width = clamp(rawWidth, WIDGET_MIN_WIDTH, maxWidth);
    const height = clamp(rawHeight, WIDGET_MIN_HEIGHT, maxHeight);

    this.extraMinimized = false;
    this.widgetWidth = width;
    this.widgetHeight = height;
    this.posLeft = state.onLeft ? state.anchorX - width : state.anchorX;
    this.posTop = state.onTop ? state.anchorY - height : state.anchorY;

    if (event.cancelable) {
      event.preventDefault();
    }
  }

  @action
  stopResize() {
    if (!this.resizeState) {
      return;
    }

    this.#removeResizeListeners();
    this.resizeState = null;
    this.resizing = false;
    this.#saveSize();
  }

  #removeResizeListeners() {
    window.removeEventListener("mousemove", this.resizeWidget);
    window.removeEventListener("touchmove", this.resizeWidget);
    window.removeEventListener("mouseup", this.stopResize);
    window.removeEventListener("touchend", this.stopResize);
  }

  #removeDragListeners() {
    window.removeEventListener("mousemove", this.dragWidget);
    window.removeEventListener("touchmove", this.dragWidget);
    window.removeEventListener("mouseup", this.stopDrag);
    window.removeEventListener("touchend", this.stopDrag);
  }

  #eventPoint(event) {
    const touch =
      event.touches?.[0] ||
      event.changedTouches?.[0] ||
      (event.clientX != null ? event : null);
    return touch ? { x: touch.clientX, y: touch.clientY } : null;
  }

  @action
  leaveRoom() {
    this.voiceWebrtc.leave(this.room);
  }

  @action
  expandWidget() {
    this.extraMinimized = false;
    this.widgetWidth = null;
    this.widgetHeight = null;
    this.posLeft = null;
    this.posTop = null;
    this.#saveSize();
  }

  @action
  openChat() {
    if (this.room?.slug) {
      this.router.transitionTo("voice-room", this.room.slug, {
        queryParams: { chat: true },
      });
    }
  }

  @action
  openChatFromMenu(closeMenu) {
    closeMenu?.();
    this.openChat();
  }

  @action
  openRoomInfo(closeMenu) {
    closeMenu?.();
    this.modal.show(VoiceRoomInfoModal, { model: { room: this.room } });
  }

  @action
  openInviteModal(closeMenu) {
    closeMenu?.();
    this.modal.show(VoiceInviteUsersModal, { model: { room: this.room } });
  }

  @action
  noopAspect() {}

  @action
  updateTileAreaSize(width, height, gap) {
    this.tileAreaWidth = width;
    this.tileAreaHeight = height;
    this.tileAreaGap = gap;
  }

  @action
  registerWidget(element) {
    this.widgetElement = element;
    this.watchWidgetRoom();
  }

  @action
  watchWidgetRoom() {
    const roomId = this.room?.id;
    if (!roomId) {
      return;
    }

    next(this, () => {
      if (this.isDestroying || this.isDestroyed || this.room?.id !== roomId) {
        return;
      }

      this.voiceWebrtc.setWatching(roomId, true);
    });
  }

  stopWatchingWidgetRoom() {
    const roomId = this.room?.id;
    if (roomId) {
      this.voiceWebrtc.setWatching(roomId, false, { keepVideo: true });
    }
  }

  <template>
    {{! eslint-disable ember/template-no-pointer-down-event-binding, ember/template-no-invalid-interactive }}
    {{#if this.shouldRender}}
      <section
        class={{dConcatClass
          "voice-call-widget"
          (if this.resizing "--resizing")
          (if this.dragging "--dragging")
          (if this.extraMinimized "--extra-minimized")
        }}
        style={{this.widgetStyle}}
        data-room-id={{this.room.id}}
        aria-label={{i18n "voice.widget.title" room=this.room.name}}
        {{didInsert this.registerWidget}}
        {{didInsert this.watchWidgetRoom this.room.id}}
        {{on "pointermove" this.dragWidget}}
        {{on "pointerup" this.stopDrag}}
        {{on "pointercancel" this.stopDrag}}
      >
        {{#unless this.extraMinimized}}
          <header class="voice-call-widget__header">
            <div
              class="voice-call-widget__room"
              role="heading"
              aria-level="2"
              {{on "mousedown" this.startDrag}}
              {{on "touchstart" this.startDrag}}
            >
              <span
                class="voice-call-widget__room-name"
              >{{this.room.name}}</span>
              <VoiceRecordingBadge @room={{this.room}} />
              <VoiceTranscriptBadge @room={{this.room}} />
            </div>
          </header>

          <div
            class="voice-call-widget__tiles"
            style={{this.tilesStyle}}
            {{trackGridSize this.updateTileAreaSize}}
          >
            {{#each this.tiles key="participant.id" as |tile|}}
              <VoiceVideoTile
                @room={{this.room}}
                @participant={{tile.participant}}
                @isSelf={{tile.isSelf}}
                @showVideo={{tile.showVideo}}
                @onAspect={{this.noopAspect}}
              />
            {{/each}}

            {{#each this.ringingEntries key="user.id" as |entry|}}
              <VoiceRingingTile @user={{entry.user}} />
            {{/each}}

            {{#if this.overflowCount}}
              <button
                type="button"
                class="voice-call-widget__overflow-tile"
                title={{this.overflowTitle}}
                aria-label={{this.overflowTitle}}
                {{on "click" this.openRoom}}
              >
                <span
                  class="voice-call-widget__overflow-avatars"
                  aria-hidden="true"
                >
                  {{#each this.overflowAvatars key="id" as |avatar|}}
                    <img src={{avatar.src}} alt="" />
                  {{/each}}
                </span>
                <span
                  class="voice-call-widget__overflow-count"
                  aria-hidden="true"
                >{{this.overflowLabel}}</span>
              </button>
            {{/if}}
          </div>
        {{/unless}}

        <footer class="voice-call-widget__controls">
          {{#if this.extraMinimized}}
            <DButton
              @action={{this.expandWidget}}
              @icon="expand"
              @translatedTitle={{this.expandWidgetTitle}}
              class="voice-call-widget__expand"
            />
          {{else}}
            <VoiceCallControls @room={{this.room}} />
            <DButton
              @action={{this.openRoom}}
              @icon="expand"
              @translatedTitle={{this.openRoomTitle}}
              class="btn-default"
            />
            <DMenu
              @identifier="voice-widget-room-menu"
              @icon="ellipsis-vertical"
              @title={{i18n "voice.room.more"}}
              @ariaLabel={{i18n "voice.room.more"}}
              @placement="top-end"
              @modalForMobile={{true}}
              @triggerClass="btn-default"
            >
              <:content as |roomMenu|>
                <DDropdownMenu as |dropdown|>
                  {{#if this.chatAvailable}}
                    <dropdown.item>
                      <DButton
                        @action={{fn this.openChatFromMenu roomMenu.close}}
                        @icon="far-comment"
                        @translatedLabel={{this.chatTitle}}
                        class="btn-transparent"
                      />
                    </dropdown.item>
                  {{/if}}
                  {{#if this.room.can_invite}}
                    <dropdown.item>
                      <DButton
                        @action={{fn this.openInviteModal roomMenu.close}}
                        @icon="user-plus"
                        @label="voice.invite.menu"
                        class="btn-transparent"
                      />
                    </dropdown.item>
                  {{/if}}
                  <dropdown.item>
                    <DButton
                      @action={{fn this.openRoomInfo roomMenu.close}}
                      @icon="circle-info"
                      @label="voice.room.info"
                      class="btn-transparent"
                    />
                  </dropdown.item>
                </DDropdownMenu>
              </:content>
            </DMenu>
          {{/if}}
          <DButton
            @action={{this.leaveRoom}}
            @icon="phone-slash"
            @ariaLabel="voice.room.leave"
            class="btn-danger voice-call-widget__leave"
          />
        </footer>

        {{#unless this.capabilities.touch}}
          {{#each this.resizeCorners as |corner|}}
            {{#unless this.extraMinimized}}
              <div
                class={{dConcatClass
                  "voice-call-widget__resize"
                  (concat "--" corner)
                }}
                aria-hidden="true"
                {{on "mousedown" (fn this.startResize corner)}}
                {{on "touchstart" (fn this.startResize corner)}}
              ></div>
            {{/unless}}
          {{/each}}
        {{/unless}}
      </section>
    {{/if}}
  </template>
}
