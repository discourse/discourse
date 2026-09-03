import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { waitForPromise } from "@ember/test-waiters";
import {
  lookupCachedUploadUrl,
  lookupUncachedUploadUrls,
  MISSING,
} from "pretty-text/upload-short-url";
import { NodeSelection } from "prosemirror-state";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const UNRESOLVED_MEDIA_PATHS = ["/404", "/images/transparent.png"];

function resolvedUrl(url) {
  return url &&
    url !== MISSING &&
    !UNRESOLVED_MEDIA_PATHS.some((path) => url.endsWith(path))
    ? url
    : null;
}

function videoThumbnailShortUrl(url) {
  return url?.match(/^(upload:\/\/[a-zA-Z0-9]+)(?:\.[a-z0-9]+)?$/i)?.[1];
}

export default class VideoNodeView extends Component {
  @service a11y;

  @tracked error;
  @tracked isActivated = false;
  @tracked isPlaybackRequested = false;
  @tracked poster;
  @tracked source;

  #loadId = 0;
  #originalSrc;
  #playId = 0;
  #playPending = false;
  #video;

  constructor() {
    super(...arguments);

    this.args.dom.classList.remove("composer-image-node");
    this.args.dom.classList.add("composer-video-node");
    this.#originalSrc = this.args.node.attrs.originalSrc;
    this.args.onSetup?.(this);
    this.#load(this.args.node);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.#loadId++;
    this.#playId++;
    this.#playPending = false;
    this.args.dom.classList.remove(
      "composer-video-node",
      "ProseMirror-selectednode"
    );
    this.args.dom.classList.add("composer-image-node");
  }

  @action
  activateVideo() {
    this.error = null;
    this.isActivated = true;
  }

  deselectNode() {
    this.args.dom.classList.remove("ProseMirror-selectednode");
  }

  @action
  handlePlaybackError() {
    if (this.source) {
      this.#setError(
        "cannot_render_video",
        this.#playPending ? "assertive" : "polite"
      );
    }
  }

  @action
  async playVideo() {
    const playId = ++this.#playId;

    if (!this.source) {
      const loaded = await this.#load(this.args.node, { retryMissing: true });
      if (!loaded || playId !== this.#playId) {
        return;
      }
    }

    this.error = null;
    this.isPlaybackRequested = true;
    await new Promise((resolve) => schedule("afterRender", resolve));
    if (playId !== this.#playId) {
      return;
    }

    this.#playPending = true;

    try {
      await this.#video.play();
    } catch {
      if (playId === this.#playId) {
        this.#setError("cannot_render_video", "assertive");
      }
    } finally {
      if (playId === this.#playId) {
        this.#playPending = false;
      }
    }
  }

  @action
  selectVideo() {
    const pos = this.args.getPos();
    const tr = this.args.view.state.tr.setSelection(
      NodeSelection.create(this.args.view.state.doc, pos)
    );

    this.args.view.dispatch(tr);
    this.args.view.focus();
  }

  selectNode() {
    this.args.dom.classList.add("ProseMirror-selectednode");
  }

  @action
  setupVideo(video) {
    this.#video = video;
  }

  stopEvent(event) {
    if (
      ["dragstart", "dragover", "dragend", "drop", "dragleave"].includes(
        event.type
      )
    ) {
      return false;
    }

    return (
      event.target instanceof HTMLVideoElement ||
      event.target.closest?.(".composer-video-node__play")
    );
  }

  update(node) {
    if (node.attrs.originalSrc !== this.#originalSrc) {
      this.isActivated = false;
      this.isPlaybackRequested = false;
      this.#playId++;
      this.#playPending = false;
      this.#originalSrc = node.attrs.originalSrc;
    }

    this.#load(node);
  }

  async #load(node, { retryMissing = false } = {}) {
    const loadId = ++this.#loadId;
    this.error = null;
    this.source = resolvedUrl(node.attrs.src);
    this.poster = null;

    const sourceShortUrl = node.attrs.originalSrc;
    const posterShortUrl = videoThumbnailShortUrl(sourceShortUrl);
    const shortUrls = [
      ...new Set(
        [sourceShortUrl, posterShortUrl].filter((url) => {
          const cachedUrl = lookupCachedUploadUrl(url).url;
          return url && (!cachedUrl || (retryMissing && cachedUrl === MISSING));
        })
      ),
    ];

    const promise =
      shortUrls.length > 0
        ? lookupUncachedUploadUrls(shortUrls, ajax)
        : Promise.resolve();

    try {
      await waitForPromise(promise);
    } catch {
      if (loadId === this.#loadId) {
        this.#setError("invalid_video_url", "polite");
      }
      return false;
    }

    if (loadId !== this.#loadId) {
      return false;
    }

    this.source =
      resolvedUrl(lookupCachedUploadUrl(sourceShortUrl).url) ?? this.source;
    this.poster =
      resolvedUrl(lookupCachedUploadUrl(posterShortUrl).url) ?? this.poster;

    // The server resolves the extensionless short URL to the video's own
    // upload when no thumbnail was generated. A video is not a usable poster.
    if (this.poster && this.poster === this.source) {
      this.poster = null;
    }

    if (!this.source) {
      this.#setError("invalid_video_url", "polite");
      return false;
    }

    return true;
  }

  #setError(key, announcementLevel) {
    if (this.error === key) {
      return;
    }

    this.error = key;
    if (announcementLevel) {
      this.a11y.announce(i18n(key), announcementLevel);
    }
  }

  <template>
    <video
      class={{dConcatClass
        "composer-video-node__video"
        (unless this.isActivated "is-inactive")
      }}
      aria-label={{@node.attrs.alt}}
      src={{if this.isPlaybackRequested this.source}}
      poster={{this.poster}}
      controls
      playsinline
      preload="metadata"
      contenteditable="false"
      {{didInsert this.setupVideo}}
      {{on "click" this.selectVideo}}
      {{on "error" this.handlePlaybackError}}
      {{on "playing" this.activateVideo}}
    ></video>
    {{#if this.error}}
      <div class="notice error composer-video-node__error">
        {{dIcon "triangle-exclamation"}}
        {{i18n this.error}}
      </div>
    {{/if}}
    {{#unless this.isActivated}}
      <DButton
        class="btn-flat composer-video-node__play"
        @action={{this.playVideo}}
        @icon="play"
        @title="play_video"
      />
    {{/unless}}
  </template>
}
