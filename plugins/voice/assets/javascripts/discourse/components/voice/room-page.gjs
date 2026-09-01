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
import discourseLater from "discourse/lib/later";
import { defaultHomepage } from "discourse/lib/utilities";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { toggleFullscreen, trackFullscreen } from "../../lib/voice/fullscreen";
import { activeRingingEntries } from "../../lib/voice/ringing";
import { speakQueue } from "../../lib/voice/speak-queue";
import {
  bestRowHeight,
  DEFAULT_TILE_ASPECT,
  trackGridSize,
} from "../../lib/voice/video-grid-layout";
import VoiceInviteUsersModal from "../modal/voice-invite-users";
import VoiceRoomInfoModal from "../modal/voice-room-info";
import VoiceCallControls from "./call-controls";
import VoiceCallSubmenu from "./call-submenu";
import VoiceCaptionOverlay from "./caption-overlay";
import VoiceChatPanel from "./chat-panel";
import VoiceRecordingBadge from "./recording-badge";
import VoiceRingingTile from "./ringing-tile";
import VoiceSpeakQueue from "./speak-queue";
import VoiceTranscriptBadge from "./transcript-badge";
import VoiceVideoTile from "./video-tile";

const ROOM_MENU = "voice-room-menu";
const SUBMENU = "voice-call-submenu";
// Keep in sync with the `voice-room` path in voice-route-map.js
const ROOM_PATH_PREFIX = "/voice/r/";

const MOBILE_VIDEO_TILE_BUDGET = 4;
const LAYOUT_PRESENTATION = "presentation";
const LAYOUT_TILED = "tiled";

export default class VoiceRoomPage extends Component {
  @service capabilities;
  @service currentUser;
  @service menu;
  @service modal;
  @service routeHistory;
  @service router;
  @service voiceRooms;
  @service voiceWebrtc;

  @tracked gridWidth = 0;
  @tracked gridHeight = 0;
  @tracked gridGap = 0;
  @tracked tileAspects = new Map();
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
    const voiceWebrtc = this.voiceWebrtc;
    const roomId = this.args.room.id;
    const keepVideo = voiceWebrtc.isActiveRoom(roomId);

    next(() => {
      voiceWebrtc.setWatching(roomId, false, { keepVideo });
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
      this.voiceRooms.rooms.find((room) => room.id === this.args.room.id) ??
      this.args.room
    );
  }

  get connectionState() {
    return this.voiceWebrtc.connectionStateFor(this.room.id);
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
      ? i18n("voice.video.exit_fullscreen")
      : i18n("voice.video.fullscreen_all");
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

    const aspects = [
      ...this.tiles.map(
        (tile) =>
          this.tileAspects.get(tile.participant.id) ?? DEFAULT_TILE_ASPECT
      ),
      ...this.ringingEntries.map(() => DEFAULT_TILE_ASPECT),
    ];

    const rowHeight = bestRowHeight(
      this.gridWidth,
      this.gridHeight,
      aspects,
      this.gridGap
    );

    if (rowHeight <= 0) {
      return null;
    }

    return trustHTML(`--voice-tile-height: ${rowHeight}px;`);
  }

  get chatAvailable() {
    return this.room.chat_available;
  }

  get chatVisible() {
    return this.chatOpen && this.joined && this.chatAvailable;
  }

  get chatToggleTitle() {
    return this.chatOpen ? i18n("voice.chat.close") : i18n("voice.chat.open");
  }

  get chatRendered() {
    return this.chatVisible || this.chatClosing;
  }

  get transcriptAvailable() {
    return this.voiceWebrtc.subtitlesAvailable;
  }

  get transcribing() {
    return this.voiceWebrtc.isTranscribingRoom(this.room.id);
  }

  get transcriptToggleTitle() {
    return this.transcribing
      ? i18n("voice.transcript.stop")
      : i18n("voice.transcript.start");
  }

  get transcriptDraftable() {
    return (
      this.voiceWebrtc.transcriptEntries.length > 0 &&
      Number(this.voiceWebrtc.transcriptEntriesRoomId) === Number(this.room.id)
    );
  }

  get transcriptDraftLabel() {
    return this.transcribing
      ? i18n("voice.transcript.stop_and_open")
      : i18n("voice.transcript.draft_topic");
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
      if (this.isDestroying || this.isDestroyed) {
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
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.voiceWebrtc.setWatching(this.args.room.id, true);
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
  reportTileAspect(participantId, aspect) {
    const current = this.tileAspects.get(participantId) ?? null;
    if (current === aspect) {
      return;
    }

    const nextAspects = new Map(this.tileAspects);
    if (aspect) {
      nextAspects.set(participantId, aspect);
    } else {
      nextAspects.delete(participantId);
    }
    this.tileAspects = nextAspects;
  }

  @action
  joinRoom() {
    if (!this.currentUser) {
      getOwner(this).lookup("route:application").send("showLogin");
      return;
    }
    this.voiceWebrtc.join(this.room);

    // `?widget` asks for the call to live in the floating widget, which is a
    // preference the join consumes, the same way `?chat` opens the chat panel.
    if (this.args.dockOnJoin) {
      this.voiceWebrtc.setCallWidgetHidden(false);
      this.dockRoom();
    }
  }

  @action
  leaveRoom() {
    this.voiceWebrtc.leave(this.room);
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
    this.router.replaceWith(`discovery.${defaultHomepage()}`);
  }

  @action
  toggleChat() {
    this.setChatOpen(!this.chatOpen);
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
    this.modal.show(VoiceRoomInfoModal, { model: { room: this.room } });
  }

  @action
  openInviteModal(closeMenu) {
    closeMenu?.();
    this.modal.show(VoiceInviteUsersModal, { model: { room: this.room } });
  }

  @action
  dockAndClose(closeMenu) {
    closeMenu?.();
    this.dockRoom();
  }

  @action
  toggleChatFromMenu(closeMenu) {
    closeMenu?.();
    this.toggleChat();
  }

  @action
  toggleTranscriptFromMenu(closeMenu) {
    closeMenu?.();
    this.voiceWebrtc.toggleTranscriptRecording(this.room.id);
  }

  @action
  draftTranscriptTopic(closeMenu) {
    closeMenu?.();
    this.voiceWebrtc.openTranscriptDraft();
  }

  @action
  openLayoutMenu(_actionArg, event) {
    this.#openSubmenu(
      event,
      ROOM_MENU,
      [
        {
          id: LAYOUT_PRESENTATION,
          label: i18n("voice.video.layout_presentation"),
          icon: "person-chalkboard",
          selected: this.presentationLayout,
        },
        {
          id: LAYOUT_TILED,
          label: i18n("voice.video.layout_tiled"),
          icon: "table-cells",
          selected: this.tiledLayout,
        },
      ],
      this.setLayoutMode
    );
  }

  #isPublishing(participant) {
    if (participant.id === this.currentUser?.id) {
      return !!this.voiceWebrtc.localVideoKind;
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
      component: VoiceCallSubmenu,
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
        "voice-room-page"
        (if this.chatVisible "--chat-open")
        (if this.presentationLayout "--presentation")
        (if this.tiledLayout "--tiled")
      }}
      {{didInsert this.watchRoom}}
      {{didInsert this.autoJoinIfRequested}}
      {{didUpdate this.reconcileSpotlight this.participants}}
    >
      <div class="voice-room-page__body">
        <div class="voice-room-page__main">
          <header class="voice-room-page__header">
            <div class="voice-room-page__title-row">
              <h1 class="voice-room-page__title">{{this.room.name}}</h1>
              <VoiceRecordingBadge @room={{this.room}} />
              <VoiceTranscriptBadge @room={{this.room}} />
            </div>
            {{#if this.room.description_excerpt}}
              <p class="voice-room-page__description">
                {{this.room.description_excerpt}}
              </p>
            {{/if}}
          </header>

          <div class="voice-room-page__stage">
            {{#if this.tiles.length}}
              {{#if this.presentationLayout}}
                <div class="voice-room-page__presentation">
                  <div class="voice-room-page__presentation-main">
                    <VoiceVideoTile
                      @isSelf={{this.presentationTile.isSelf}}
                      @onAspect={{this.reportTileAspect}}
                      @onSpotlight={{this.toggleSpotlight}}
                      @participant={{this.presentationTile.participant}}
                      @room={{this.room}}
                      @showVideo={{this.presentationTile.showVideo}}
                      @spotlighted={{this.presentationTile.spotlighted}}
                    />
                  </div>

                  {{#if
                    (or
                      this.presentationRailTiles.length
                      this.ringingEntries.length
                    )
                  }}
                    <div class="voice-room-page__presentation-rail">
                      {{#each
                        this.presentationRailTiles key="participant.id"
                        as |tile|
                      }}
                        <VoiceVideoTile
                          @isSelf={{tile.isSelf}}
                          @onAspect={{this.reportTileAspect}}
                          @onSpotlight={{this.toggleSpotlight}}
                          @participant={{tile.participant}}
                          @room={{this.room}}
                          @showVideo={{tile.showVideo}}
                          @spotlighted={{tile.spotlighted}}
                        />
                      {{/each}}
                      {{#each this.ringingEntries key="user.id" as |entry|}}
                        <VoiceRingingTile @user={{entry.user}} />
                      {{/each}}
                    </div>
                  {{/if}}
                </div>
              {{else}}
                <div
                  class="voice-room-page__grid"
                  style={{this.gridStyle}}
                  {{didInsert this.registerGrid}}
                  {{this.trackGridSize this.updateGridSize}}
                  {{this.trackFullscreen this.setGridFullscreen}}
                >
                  <button
                    aria-label={{this.gridFullscreenTitle}}
                    class="btn btn-icon no-text voice-room-page__fullscreen"
                    title={{this.gridFullscreenTitle}}
                    type="button"
                    {{on "click" this.toggleGridFullscreen}}
                  >
                    {{dIcon (if this.gridFullscreen "compress" "expand")}}
                  </button>

                  {{#each this.tiles key="participant.id" as |tile|}}
                    <VoiceVideoTile
                      @isSelf={{tile.isSelf}}
                      @onAspect={{this.reportTileAspect}}
                      @onSpotlight={{this.toggleSpotlight}}
                      @participant={{tile.participant}}
                      @room={{this.room}}
                      @showVideo={{tile.showVideo}}
                      @spotlighted={{tile.spotlighted}}
                    />
                  {{/each}}
                  {{#each this.ringingEntries key="user.id" as |entry|}}
                    <VoiceRingingTile @user={{entry.user}} />
                  {{/each}}
                </div>
              {{/if}}
            {{else}}
              <div class="voice-room-page__empty">
                {{i18n "voice.room_page.empty"}}
              </div>
            {{/if}}
            {{#if this.joined}}
              <VoiceCaptionOverlay @room={{this.room}} />
            {{/if}}

            <footer class="voice-room-page__controls">
              {{#if this.joined}}
                <VoiceCallControls @room={{this.room}} />
                {{#if this.isStageRoom}}
                  <DMenu
                    @ariaLabel={{i18n "voice.stage.queue_title"}}
                    @identifier="voice-speak-queue-menu"
                    @modalForMobile={{true}}
                    @placement="top-end"
                    @title={{i18n "voice.stage.queue_title"}}
                    @triggerClass="btn-default voice-speak-queue-trigger"
                  >
                    <:trigger>
                      {{dIcon "list-ol"}}
                      {{#if this.speakQueueCount}}
                        <span
                          class="voice-speak-queue-trigger__count"
                        >{{this.speakQueueCount}}</span>
                      {{/if}}
                    </:trigger>
                    <:content>
                      <VoiceSpeakQueue @room={{this.room}} />
                    </:content>
                  </DMenu>
                {{/if}}
                <DMenu
                  @ariaLabel={{i18n "voice.room.more"}}
                  @icon="ellipsis-vertical"
                  @identifier="voice-room-menu"
                  @modalForMobile={{true}}
                  @placement="top-end"
                  @title={{i18n "voice.room.more"}}
                  @triggerClass="btn-default"
                >
                  <:content as |roomMenu|>
                    <DDropdownMenu as |dropdown|>
                      {{#if this.chatAvailable}}
                        <dropdown.item>
                          <DButton
                            class="btn-transparent"
                            @action={{fn
                              this.toggleChatFromMenu
                              roomMenu.close
                            }}
                            @icon={{if
                              this.chatVisible
                              "comment-slash"
                              "far-comment"
                            }}
                            @translatedLabel={{this.chatToggleTitle}}
                          />
                        </dropdown.item>
                      {{/if}}
                      <dropdown.item>
                        <DButton
                          class="btn-transparent voice-room-page__layout-trigger"
                          @action={{this.openLayoutMenu}}
                          @forwardEvent={{true}}
                          @icon={{this.layoutIcon}}
                          @label="voice.room.layout"
                          @suffixIcon="angle-right"
                        />
                      </dropdown.item>
                      <dropdown.item>
                        <DButton
                          class="btn-transparent"
                          @action={{fn this.dockAndClose roomMenu.close}}
                          @icon="compress"
                          @label="voice.room.widget_mode"
                        />
                      </dropdown.item>
                      {{#if this.room.can_invite}}
                        <dropdown.item>
                          <DButton
                            class="btn-transparent"
                            @action={{fn this.openInviteModal roomMenu.close}}
                            @icon="user-plus"
                            @label="voice.invite.menu"
                          />
                        </dropdown.item>
                      {{/if}}
                      {{#if this.transcriptAvailable}}
                        <dropdown.item>
                          <DButton
                            class={{dConcatClass
                              "btn-transparent voice-room-page__transcript-toggle"
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
                              class="btn-transparent voice-room-page__transcript-draft"
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
                          @label="voice.room.info"
                        />
                      </dropdown.item>
                    </DDropdownMenu>
                  </:content>
                </DMenu>
                <DButton
                  class="btn-danger voice-room-page__leave"
                  @action={{this.leaveRoom}}
                  @icon="phone-slash"
                  @label="voice.room.leave"
                />
              {{else}}
                <DButton
                  class="btn-primary voice-room-page__join"
                  @action={{this.joinRoom}}
                  @disabled={{this.connecting}}
                  @icon="phone"
                  @isLoading={{this.connecting}}
                  @label="voice.room.join"
                />
              {{/if}}
            </footer>
          </div>
        </div>

        {{#if this.chatRendered}}
          <aside
            class={{dConcatClass
              "voice-room-page__sidebar"
              (if this.chatClosing "--closing")
            }}
            {{on "animationend" this.chatAnimationEnded}}
          >
            <VoiceChatPanel @onClose={{this.closeChat}} @room={{this.room}} />
          </aside>
        {{/if}}
      </div>
    </section>
  </template>
}
