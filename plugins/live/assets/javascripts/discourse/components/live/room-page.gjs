import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { cancel, next } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DMenu from "discourse/float-kit/components/d-menu";
import { homepageNavigationDestination } from "discourse/lib/homepage-router-overrides";
import discourseLater from "discourse/lib/later";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  toggleFullscreen,
  trackFullscreen,
} from "../../lib/live/fullscreen.js";
import { activeRingingEntries } from "../../lib/live/ringing.js";
import { speakQueue } from "../../lib/live/speak-queue.js";
import {
  computeRoomGrid,
  trackGridSize,
} from "../../lib/live/video-grid-layout.js";
import LiveInviteAgentButton from "../live-invite-agent-button.gjs";
import LiveInviteUsersModal from "../modal/live-invite-users.gjs";
import LiveRoomInfoModal from "../modal/live-room-info.gjs";
import LiveCallControls from "./call-controls.gjs";
import LiveCallSubmenu from "./call-submenu.gjs";
import LiveCaptionOverlay from "./caption-overlay.gjs";
import LiveChatPanel from "./chat-panel.gjs";
import LiveLocalRecordingMenuItem from "./local-recording-menu-item.gjs";
import LiveReactionOverlay from "./reaction-overlay.gjs";
import LiveReactionPicker from "./reaction-picker.gjs";
import LiveRingingTile from "./ringing-tile.gjs";
import LiveRoomHeader from "./room-header.gjs";
import LiveSpeakQueue from "./speak-queue.gjs";
import LiveVideoTile from "./video-tile.gjs";

const ROOM_MENU = "live-room-menu";
const SUBMENU = "live-call-submenu";
// Keep in sync with the `live-room` path in live-route-map.js
const ROOM_PATH_PREFIX = "/live/r/";

const MOBILE_VIDEO_TILE_BUDGET = 4;
const LAYOUT_PRESENTATION = "presentation";
const LAYOUT_TILED = "tiled";

export default class LiveRoomPage extends Component {
  @service capabilities;
  @service currentUser;
  @service menu;
  @service modal;
  @service routeHistory;
  @service router;
  @service liveRooms;
  @service liveWebrtc;

  @tracked gridWidth = 0;
  @tracked gridHeight = 0;
  @tracked gridGap = 0;
  @tracked gridFullscreen = false;
  // Stage rooms mirror a workshop: chat panel open, presenter featured.
  @tracked chatOpen = !!this.args.openChat || this.#isStageRoom;
  @tracked chatClosing = false;
  @tracked layoutMode = this.#isStageRoom ? LAYOUT_PRESENTATION : LAYOUT_TILED;
  @tracked spotlightParticipantId = null;

  // Ring windows expire by wall clock, which nothing tracked observes — a
  // coarse ticker re-evaluates them so "Calling…" tiles disappear on time.
  @tracked ringingClock = Date.now();

  gridElement = null;
  trackGridSize = trackGridSize;
  trackFullscreen = trackFullscreen;
  #chatCloseFallback = null;
  #ringingTicker = null;

  constructor() {
    super(...arguments);
    if (this.args.room?.ephemeral) {
      this.#ringingTicker = setInterval(() => {
        this.ringingClock = Date.now();
      }, 5000);
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    clearInterval(this.#ringingTicker);
    cancel(this.#chatCloseFallback);
    const liveWebrtc = this.liveWebrtc;
    const roomId = this.args.room.id;
    const keepVideo = liveWebrtc.isActiveRoom(roomId);

    next(() => {
      liveWebrtc.setWatching(roomId, false, { keepVideo });
    });
  }

  get #isStageRoom() {
    return this.args.room?.room_type === "stage";
  }

  get isStageRoom() {
    return this.#isStageRoom;
  }

  get speakQueueCount() {
    return speakQueue(this.room).length;
  }

  get room() {
    return (
      this.liveRooms.rooms.find((room) => room.id === this.args.room.id) ??
      this.args.room
    );
  }

  get connectionState() {
    return this.liveWebrtc.connectionStateFor(this.room.id);
  }

  get joined() {
    return this.connectionState === "connected";
  }

  get connecting() {
    return this.connectionState === "connecting";
  }

  get participants() {
    return this.room.active_participants || [];
  }

  get tiles() {
    const budget = this.capabilities.viewport.md
      ? Infinity
      : MOBILE_VIDEO_TILE_BUDGET;
    const videoParticipantIds = new Set();

    const spotlightParticipant = this.participants.find(
      (participant) => participant.id === this.spotlightParticipantId
    );
    if (spotlightParticipant && this.#isPublishing(spotlightParticipant)) {
      videoParticipantIds.add(spotlightParticipant.id);
    }

    for (const participant of this.participants) {
      if (videoParticipantIds.size >= budget) {
        break;
      }
      if (this.#isPublishing(participant)) {
        videoParticipantIds.add(participant.id);
      }
    }

    return this.participants.map((participant) => {
      const isSelf = participant.id === this.currentUser?.id;
      return {
        participant,
        isSelf,
        showVideo: videoParticipantIds.has(participant.id),
        spotlighted: participant.id === this.spotlightParticipantId,
      };
    });
  }

  get ringingEntries() {
    return activeRingingEntries(this.room, this.ringingClock);
  }

  get presentationTile() {
    return (
      this.tiles.find((tile) => tile.spotlighted) ??
      this.tiles.find((tile) => tile.participant.is_screen_sharing) ??
      this.tiles.find((tile) => tile.showVideo && !tile.isSelf) ??
      this.tiles.find((tile) => tile.showVideo) ??
      this.tiles.find((tile) =>
        ["moderator", "speaker"].includes(tile.participant.role)
      ) ??
      this.tiles[0]
    );
  }

  get presentationRailTiles() {
    const featuredId = this.presentationTile?.participant.id;
    return this.tiles.filter((tile) => tile.participant.id !== featuredId);
  }

  // In a one-to-one call your own camera is the least useful tile to you, so
  // it floats in a corner and the other person gets the whole stage.
  get pipTile() {
    if (
      !this.tiledLayout ||
      this.tiles.length !== 2 ||
      this.ringingEntries.length
    ) {
      return null;
    }
    return this.tiles.find((tile) => tile.isSelf) ?? null;
  }

  get gridTiles() {
    const pipId = this.pipTile?.participant.id;
    return this.tiles.filter((tile) => tile.participant.id !== pipId);
  }

  get tiledLayout() {
    return this.layoutMode === LAYOUT_TILED;
  }

  get presentationLayout() {
    return this.layoutMode === LAYOUT_PRESENTATION;
  }

  get layoutIcon() {
    return this.presentationLayout ? "person-chalkboard" : "table-cells";
  }

  get gridFullscreenTitle() {
    return this.gridFullscreen
      ? i18n("live.video.exit_fullscreen")
      : i18n("live.video.fullscreen_all");
  }

  get gridStyle() {
    if (
      !this.tiledLayout ||
      !this.tiles.length ||
      !this.gridWidth ||
      !this.gridHeight
    ) {
      return null;
    }

    const grid = computeRoomGrid({
      width: this.gridWidth,
      height: this.gridHeight,
      count: this.gridTiles.length + this.ringingEntries.length,
      gap: this.gridGap,
    });

    if (!grid) {
      return null;
    }

    return trustHTML(
      `--live-tile-width: ${grid.tileWidth}px; --live-tile-height: ${grid.tileHeight}px; --live-grid-line-width: ${grid.lineWidth}px;`
    );
  }

  get chatAvailable() {
    return this.room.chat_available;
  }

  get chatVisible() {
    return this.chatOpen && this.joined && this.chatAvailable;
  }

  get canOpenChat() {
    return this.joined && this.chatAvailable && !this.chatVisible;
  }

  get chatRendered() {
    return this.chatVisible || this.chatClosing;
  }

  get transcriptAvailable() {
    return this.liveWebrtc.subtitlesAvailable;
  }

  get transcribing() {
    return this.liveWebrtc.isTranscribingRoom(this.room.id);
  }

  get transcriptToggleTitle() {
    return this.transcribing
      ? i18n("live.transcript.stop")
      : i18n("live.transcript.start");
  }

  get transcriptDraftable() {
    return (
      this.liveWebrtc.transcriptEntries.length > 0 &&
      Number(this.liveWebrtc.transcriptEntriesRoomId) === Number(this.room.id)
    );
  }

  get transcriptDraftLabel() {
    return this.transcribing
      ? i18n("live.transcript.stop_and_open")
      : i18n("live.transcript.draft_topic");
  }

  @action
  toggleSpotlight(participantId) {
    this.spotlightParticipantId =
      this.spotlightParticipantId === participantId ? null : participantId;
    this.layoutMode = LAYOUT_PRESENTATION;
  }

  @action
  setLayoutMode(layoutMode) {
    this.spotlightParticipantId = null;
    this.layoutMode = layoutMode;
  }

  @action
  reconcileSpotlight() {
    if (
      this.spotlightParticipantId &&
      !this.participants.some(
        (participant) => participant.id === this.spotlightParticipantId
      )
    ) {
      this.spotlightParticipantId = null;
    }
  }

  @action
  updateGridSize(width, height, gap) {
    this.gridWidth = width;
    this.gridHeight = height;
    this.gridGap = gap;
  }

  @action
  registerGrid(element) {
    this.gridElement = element;
  }

  @action
  autoJoinIfRequested() {
    if (!this.args.autoJoin) {
      return;
    }

    next(this, () => {
      if (this.isDestroying) {
        return;
      }

      // Consume the param so a refresh or back-navigation doesn't rejoin a
      // call the user has since left.
      this.router.transitionTo({ queryParams: { join: false } });

      if (!this.joined && !this.connecting) {
        this.joinRoom();
      }
    });
  }

  @action
  watchRoom() {
    next(this, () => {
      if (this.isDestroying) {
        return;
      }

      this.liveWebrtc.setWatching(this.args.room.id, true);
    });
  }

  @action
  setGridFullscreen(isFullscreen) {
    this.gridFullscreen = isFullscreen;
  }

  @action
  toggleGridFullscreen() {
    toggleFullscreen(this.gridElement);
  }

  @action
  joinRoom() {
    if (!this.currentUser) {
      getOwner(this).lookup("route:application").send("showLogin");
      return;
    }
    this.liveWebrtc.join(this.room);

    // `?widget` asks for the call to live in the floating widget, which is a
    // preference the join consumes, the same way `?chat` opens the chat panel.
    if (this.args.dockOnJoin) {
      this.liveWebrtc.setCallWidgetHidden(false);
      this.dockRoom();
    }
  }

  @action
  leaveRoom() {
    this.liveWebrtc.leave(this.room);
  }

  @action
  dockRoom() {
    // Docking keeps the call and drops the page, so the user should get their
    // place back rather than a reset: return to where they came from, replacing
    // the room page so going back does not land on it again.
    //
    // Every room page is skipped, not just the current URL: consuming `?join`
    // leaves this room in the history under a different spelling, and returning
    // to it would look like docking did nothing.
    const previousURL = this.routeHistory.history.find(
      (url) => !url.startsWith(ROOM_PATH_PREFIX)
    );

    if (previousURL) {
      this.router.replaceWith(previousURL);
      return;
    }

    // Nothing to return to, e.g. the room page was opened directly.
    this.router.replaceWith(homepageNavigationDestination());
  }

  @action
  openChat() {
    this.setChatOpen(true);
  }

  @action
  closeChat() {
    this.setChatOpen(false);
  }

  setChatOpen(open) {
    cancel(this.#chatCloseFallback);
    if (open) {
      this.chatClosing = false;
    } else if (this.chatVisible) {
      // Keep the panel mounted while its exit animation plays; unmounting is
      // deferred to chatAnimationEnded. If the animation never runs (a theme
      // or user stylesheet can disable it outright), don't leave the panel
      // mounted forever.
      this.chatClosing = true;
      this.#chatCloseFallback = discourseLater(() => {
        this.chatClosing = false;
      }, 500);
    }
    this.chatOpen = open;
    this.router.transitionTo({ queryParams: { chat: open } });
  }

  @action
  chatAnimationEnded(event) {
    if (
      event.target === event.currentTarget &&
      event.animationName.endsWith("-out")
    ) {
      cancel(this.#chatCloseFallback);
      this.chatClosing = false;
    }
  }

  @action
  openRoomInfo(closeMenu) {
    closeMenu?.();
    this.modal.show(LiveRoomInfoModal, { model: { room: this.room } });
  }

  @action
  openInviteModal(closeMenu) {
    closeMenu?.();
    this.modal.show(LiveInviteUsersModal, { model: { room: this.room } });
  }

  @action
  toggleFullscreenFromMenu(closeMenu) {
    this.toggleGridFullscreen();
    closeMenu?.();
  }

  @action
  dockAndClose(closeMenu) {
    closeMenu?.();
    this.dockRoom();
  }

  @action
  toggleTranscriptFromMenu(closeMenu) {
    closeMenu?.();
    this.liveWebrtc.toggleTranscriptRecording(this.room.id);
  }

  @action
  draftTranscriptTopic(closeMenu) {
    closeMenu?.();
    this.liveWebrtc.openTranscriptDraft();
  }

  @action
  openLayoutMenu(_actionArg, event) {
    this.#openSubmenu(
      event,
      ROOM_MENU,
      [
        {
          id: LAYOUT_PRESENTATION,
          label: i18n("live.video.layout_presentation"),
          icon: "person-chalkboard",
          selected: this.presentationLayout,
        },
        {
          id: LAYOUT_TILED,
          label: i18n("live.video.layout_tiled"),
          icon: "table-cells",
          selected: this.tiledLayout,
        },
      ],
      this.setLayoutMode
    );
  }

  #isPublishing(participant) {
    if (participant.id === this.currentUser?.id) {
      return !!this.liveWebrtc.localVideoKind;
    }
    return participant.is_video_on || participant.is_screen_sharing;
  }

  // Opened programmatically (not a nested <DMenu>) so the trigger stays a
  // normal full-width menu item, matching core's channel context menu.
  #openSubmenu(event, parentMenu, items, onSelect) {
    // Anchor to the row button, not the clicked icon/label, so the submenu
    // opens flush to the row's right edge.
    const anchor = event.target.closest(".btn") ?? event.target;
    this.menu.show(anchor, {
      identifier: SUBMENU,
      groupIdentifier: SUBMENU,
      component: LiveCallSubmenu,
      placement: "right-start",
      offset: { mainAxis: 8, crossAxis: -5 },
      modalForMobile: true,
      data: {
        items,
        onSelect: (id) => {
          onSelect(id);
          this.menu.close(parentMenu);
        },
      },
    });
  }

  <template>
    <section
      class={{dConcatClass
        "live-room-page"
        (if this.chatVisible "--chat-open")
        (if this.presentationLayout "--presentation")
        (if this.tiledLayout "--tiled")
      }}
      {{didInsert this.watchRoom}}
      {{didInsert this.autoJoinIfRequested}}
      {{didUpdate this.reconcileSpotlight this.participants}}
    >

      <div class="live-room-page__main">
        <LiveRoomHeader
          @canOpenChat={{this.canOpenChat}}
          @onOpenChat={{this.openChat}}
          @room={{this.room}}
        />

        <div class="live-room-page__stage">
          {{#if this.tiles.length}}
            {{#if this.presentationLayout}}
              <div class="live-room-page__presentation">
                <div class="live-room-page__presentation-main">
                  <LiveVideoTile
                    @isSelf={{this.presentationTile.isSelf}}
                    @onSpotlight={{this.toggleSpotlight}}
                    @participant={{this.presentationTile.participant}}
                    @room={{this.room}}
                    @showVideo={{this.presentationTile.showVideo}}
                    @spotlighted={{this.presentationTile.spotlighted}}
                  />
                </div>

                {{#if
                  (or
                    this.presentationRailTiles.length this.ringingEntries.length
                  )
                }}
                  <div class="live-room-page__presentation-rail">
                    {{#each
                      this.presentationRailTiles key="participant.id"
                      as |tile|
                    }}
                      <LiveVideoTile
                        @isSelf={{tile.isSelf}}
                        @onSpotlight={{this.toggleSpotlight}}
                        @participant={{tile.participant}}
                        @room={{this.room}}
                        @showVideo={{tile.showVideo}}
                        @spotlighted={{tile.spotlighted}}
                      />
                    {{/each}}
                    {{#each this.ringingEntries key="user.id" as |entry|}}
                      <LiveRingingTile @user={{entry.user}} />
                    {{/each}}
                  </div>
                {{/if}}
              </div>
            {{else}}
              <div
                class="live-room-page__grid"
                style={{this.gridStyle}}
                {{didInsert this.registerGrid}}
                {{this.trackGridSize this.updateGridSize}}
                {{this.trackFullscreen this.setGridFullscreen}}
              >
                {{#if this.gridFullscreen}}
                  <DButton
                    class="btn-icon no-text live-room-page__fullscreen"
                    @action={{this.toggleGridFullscreen}}
                    @icon="discourse-compress"
                    @translatedAriaLabel={{this.gridFullscreenTitle}}
                    @translatedTitle={{this.gridFullscreenTitle}}
                  />
                {{/if}}
                <div class="live-room-page__tiles">
                  {{#each this.gridTiles key="participant.id" as |tile|}}
                    <LiveVideoTile
                      @isSelf={{tile.isSelf}}
                      @onSpotlight={{this.toggleSpotlight}}
                      @participant={{tile.participant}}
                      @room={{this.room}}
                      @showVideo={{tile.showVideo}}
                      @spotlighted={{tile.spotlighted}}
                    />
                  {{/each}}
                  {{#each this.ringingEntries key="user.id" as |entry|}}
                    <LiveRingingTile @user={{entry.user}} />
                  {{/each}}
                </div>
                {{#if this.pipTile}}
                  <LiveVideoTile
                    class="live-room-page__pip"
                    @isSelf={{this.pipTile.isSelf}}
                    @onSpotlight={{this.toggleSpotlight}}
                    @participant={{this.pipTile.participant}}
                    @room={{this.room}}
                    @showVideo={{this.pipTile.showVideo}}
                    @spotlighted={{this.pipTile.spotlighted}}
                  />
                {{/if}}
              </div>
            {{/if}}
          {{else}}
            <div class="live-room-page__empty">
              {{i18n "live.room_page.empty"}}
            </div>
          {{/if}}
          {{#if this.joined}}
            <LiveCaptionOverlay @room={{this.room}} />
            <LiveReactionOverlay @room={{this.room}} />
          {{/if}}

          <footer class="live-room-page__controls">
            {{#if this.joined}}
              <LiveCallControls @room={{this.room}} />
              <LiveReactionPicker @room={{this.room}} />
              {{#if this.isStageRoom}}
                <DMenu
                  @ariaLabel={{i18n "live.stage.queue_title"}}
                  @identifier="live-speak-queue-menu"
                  @modalForMobile={{true}}
                  @placement="top-end"
                  @title={{i18n "live.stage.queue_title"}}
                  @triggerClass="btn-default live-speak-queue-trigger"
                >
                  <:trigger>
                    {{dIcon "list-ol"}}
                    {{#if this.speakQueueCount}}
                      <span
                        class="live-speak-queue-trigger__count"
                      >{{this.speakQueueCount}}</span>
                    {{/if}}
                  </:trigger>
                  <:content>
                    <LiveSpeakQueue @room={{this.room}} />
                  </:content>
                </DMenu>
              {{/if}}
              <DMenu
                @ariaLabel={{i18n "live.room.more"}}
                @icon="ellipsis-vertical"
                @identifier="live-room-menu"
                @modalForMobile={{true}}
                @placement="top-end"
                @title={{i18n "live.room.more"}}
                @triggerClass="btn-default"
              >
                <:content as |roomMenu|>
                  <DDropdownMenu as |dropdown|>
                    <LiveInviteAgentButton
                      @closeMenu={{roomMenu.close}}
                      @item={{dropdown.item}}
                      @room={{this.room}}
                    />
                    <LiveLocalRecordingMenuItem
                      @closeMenu={{roomMenu.close}}
                      @item={{dropdown.item}}
                      @room={{this.room}}
                    />
                    <dropdown.item>
                      <DButton
                        class="btn-transparent live-room-page__layout-trigger"
                        @action={{this.openLayoutMenu}}
                        @forwardEvent={{true}}
                        @icon={{this.layoutIcon}}
                        @label="live.room.layout"
                        @suffixIcon="angle-right"
                      />
                    </dropdown.item>
                    <dropdown.item>
                      <DButton
                        class="btn-transparent"
                        @action={{fn this.dockAndClose roomMenu.close}}
                        @icon="picture-in-picture"
                        @label="live.room.widget_mode"
                      />
                    </dropdown.item>
                    {{#if (and this.tiledLayout this.tiles.length)}}
                      <dropdown.item>
                        <DButton
                          class="btn-transparent live-room-page__fullscreen-trigger"
                          @icon="discourse-expand"
                          @translatedLabel={{this.gridFullscreenTitle}}
                          {{on
                            "click"
                            (fn this.toggleFullscreenFromMenu roomMenu.close)
                          }}
                        />
                      </dropdown.item>
                    {{/if}}
                    {{#if this.room.can_invite}}
                      <dropdown.item>
                        <DButton
                          class="btn-transparent"
                          @action={{fn this.openInviteModal roomMenu.close}}
                          @icon="user-plus"
                          @label="live.invite.menu"
                        />
                      </dropdown.item>
                    {{/if}}
                    {{#if this.transcriptAvailable}}
                      <dropdown.item>
                        <DButton
                          class={{dConcatClass
                            "btn-transparent live-room-page__transcript-toggle"
                            (if this.transcribing "--recording")
                          }}
                          @action={{fn
                            this.toggleTranscriptFromMenu
                            roomMenu.close
                          }}
                          @icon={{if
                            this.transcribing
                            "stop"
                            "closed-captioning"
                          }}
                          @translatedLabel={{this.transcriptToggleTitle}}
                        />
                      </dropdown.item>
                      {{#if this.transcriptDraftable}}
                        <dropdown.item>
                          <DButton
                            class="btn-transparent live-room-page__transcript-draft"
                            @action={{fn
                              this.draftTranscriptTopic
                              roomMenu.close
                            }}
                            @icon="far-file-lines"
                            @translatedLabel={{this.transcriptDraftLabel}}
                          />
                        </dropdown.item>
                      {{/if}}
                    {{/if}}
                    <dropdown.item>
                      <DButton
                        class="btn-transparent"
                        @action={{fn this.openRoomInfo roomMenu.close}}
                        @icon="circle-info"
                        @label="live.room.info"
                      />
                    </dropdown.item>
                  </DDropdownMenu>
                </:content>
              </DMenu>
              <DButton
                class="btn-danger live-room-page__leave"
                @action={{this.leaveRoom}}
                @icon="phone-slash"
                @label="live.room.leave"
              />
            {{else}}
              <DButton
                class="btn-primary live-room-page__join"
                @action={{this.joinRoom}}
                @disabled={{this.connecting}}
                @icon="phone"
                @isLoading={{this.connecting}}
                @label="live.room.join"
              />
            {{/if}}
          </footer>
        </div>
      </div>

      {{#if this.chatRendered}}
        <aside
          class={{dConcatClass
            "chat-side-panel"
            (if this.chatClosing "--closing")
          }}
          {{on "animationend" this.chatAnimationEnded}}
        >
          <LiveChatPanel @onClose={{this.closeChat}} @room={{this.room}} />
        </aside>
      {{/if}}

    </section>
  </template>
}
