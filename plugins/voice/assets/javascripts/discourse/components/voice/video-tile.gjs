import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { avatarUrl } from "discourse/lib/avatar-utils";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  toggleTileFullscreen,
  trackFullscreen,
} from "../../lib/voice/fullscreen";
import {
  DEFAULT_TILE_ASPECT,
  trackVideoAspect,
} from "../../lib/voice/video-grid-layout";
import virtualElementFromEvent from "../../lib/voice/virtual-element-from-event";
import VoiceParticipantSidebarContextMenu from "../voice-participant-sidebar-context-menu";

export default class VoiceVideoTile extends Component {
  @service menu;
  @service voiceRooms;
  @service voiceWebrtc;

  @tracked aspect = null;
  @tracked isFullscreen = false;

  trackVideoAspect = trackVideoAspect;
  trackFullscreen = trackFullscreen;

  get participant() {
    return this.args.participant;
  }

  get isSpeaking() {
    return this.voiceRooms.isParticipantSpeaking(
      this.args.room?.id,
      this.participant.id
    );
  }

  get tileStyle() {
    return trustHTML(`aspect-ratio: ${this.aspect ?? DEFAULT_TILE_ASPECT};`);
  }

  @action
  handleAspect(aspect) {
    this.aspect = aspect;
    this.args.onAspect?.(this.participant.id, aspect);
  }

  @action
  setFullscreen(isFullscreen) {
    this.isFullscreen = isFullscreen;
  }

  @action
  toggleFullscreen(event) {
    toggleTileFullscreen(event.currentTarget.closest(".voice-video-tile"));
  }

  // The menu only offers audio controls for a call the user is in, so
  // page visitors who haven't joined the room don't get one.
  get canShowMenu() {
    return (
      this.voiceWebrtc.connectionStateFor(this.args.room?.id) === "connected"
    );
  }

  @action
  openContextMenu(event) {
    if (!this.canShowMenu) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();
    this.#showParticipantMenu(virtualElementFromEvent(event), "bottom-start");
  }

  @action
  openTileMenu(event) {
    event.stopPropagation();
    this.#showParticipantMenu(event.currentTarget, "top-end");
  }

  #showParticipantMenu(anchor, placement) {
    this.menu.show(anchor, {
      identifier: "voice-participant-menu",
      component: VoiceParticipantSidebarContextMenu,
      placement,
      modalForMobile: true,
      data: {
        room: this.args.room,
        participant: this.participant,
        canManageRoom: this.args.room?.can_manage,
        isCurrentUser: this.args.isSelf,
        isSpotlighted: this.args.spotlighted,
        onSpotlight: this.args.onSpotlight,
      },
    });
  }

  get fullscreenTitle() {
    return this.isFullscreen
      ? i18n("voice.video.exit_fullscreen")
      : i18n("voice.video.fullscreen");
  }

  get stream() {
    if (this.args.isSelf) {
      return this.voiceWebrtc.localVideoStream;
    }

    return this.voiceWebrtc.remoteStreamFor(
      this.args.room.id,
      this.participant.id
    );
  }

  get publishingKind() {
    if (this.args.isSelf) {
      return this.voiceWebrtc.localVideoKind;
    }

    if (this.participant.is_screen_sharing) {
      return "screen";
    }

    if (this.participant.is_video_on) {
      return "camera";
    }

    return null;
  }

  get showVideo() {
    return this.args.showVideo && !!this.publishingKind && !!this.stream;
  }

  get avatarSrc() {
    return avatarUrl(this.participant.avatar_template, "huge");
  }

  get displayName() {
    return prioritizeNameInUx(this.participant.name)
      ? this.participant.name
      : this.participant.username;
  }

  <template>
    <div
      class={{dConcatClass
        "voice-video-tile"
        (if this.showVideo "--video" "--avatar")
        (if (eq this.publishingKind "screen") "--screen")
        (if @isSelf "--self")
        (if this.isSpeaking "--speaking")
      }}
      data-user-id={{this.participant.id}}
      style={{this.tileStyle}}
      {{this.trackFullscreen this.setFullscreen}}
      {{on "contextmenu" this.openContextMenu}}
    >
      {{#if this.showVideo}}
        <video
          class="voice-video-tile__video"
          {{didInsert (fn this.voiceWebrtc.attachVideoStream this.stream)}}
          {{didUpdate
            (fn this.voiceWebrtc.attachVideoStream this.stream)
            this.stream
          }}
          {{this.trackVideoAspect this.handleAspect}}
          muted
          autoplay
          playsinline
        ></video>
      {{else}}
        <div class="voice-video-tile__avatar">
          <img src={{this.avatarSrc}} alt={{this.displayName}} />
        </div>
      {{/if}}

      <div class="voice-video-tile__info">
        <span class="voice-video-tile__name">{{this.displayName}}</span>
        {{#if this.participant.is_muted}}
          {{dIcon "microphone-slash"}}
        {{/if}}
        {{#if this.participant.is_deafened}}
          {{dIcon "volume-xmark"}}
        {{/if}}
        {{#if (eq this.publishingKind "screen")}}
          {{dIcon "display"}}
        {{/if}}
      </div>

      {{#if this.canShowMenu}}
        <button
          type="button"
          class="btn btn-icon no-text voice-video-tile__menu"
          title={{i18n "voice.participant.menu_title"}}
          aria-label={{i18n "voice.participant.menu_title"}}
          {{on "click" this.openTileMenu}}
        >
          {{dIcon "ellipsis-vertical"}}
        </button>
      {{/if}}

      {{#if this.showVideo}}
        <button
          type="button"
          class="btn btn-icon no-text voice-video-tile__fullscreen"
          title={{this.fullscreenTitle}}
          aria-label={{this.fullscreenTitle}}
          {{on "click" this.toggleFullscreen}}
        >
          {{dIcon (if this.isFullscreen "compress" "expand")}}
        </button>
      {{/if}}
    </div>
  </template>
}
