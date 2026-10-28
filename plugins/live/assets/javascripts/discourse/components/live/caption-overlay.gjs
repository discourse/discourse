import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import { fullscreenElement } from "../../lib/live/fullscreen.js";

const MAX_VISIBLE_LINES = 3;
const LINE_TTL_MS = 10000;
const PRUNE_INTERVAL_MS = 1000;
const FULLSCREEN_HOSTS = ".live-room-page__grid, .live-video-tile";

const CaptionLines = <template>
  <div
    aria-live="polite"
    class="live-captions {{if @fullscreen '--fullscreen'}}"
  >
    {{#if @showLoading}}
      <p class="live-captions__line --loading">
        {{@loadingLabel}}
      </p>
    {{else}}
      {{#each @captions key="id" as |caption|}}
        <p class="live-captions__line {{if caption.interim '--interim'}}">
          {{#if caption.username}}
            <span class="live-captions__speaker">{{caption.username}}</span>
          {{/if}}
          {{caption.text}}
        </p>
      {{/each}}
    {{/if}}
  </div>
</template>;

export default class LiveCaptionOverlay extends Component {
  @service liveWebrtc;

  // Bumped on a timer so lines fall off the overlay once they go stale,
  // not only when a newer caption pushes them out.
  @tracked now = Date.now();

  // Only the fullscreen element's subtree is painted while fullscreen, so the
  // overlay has to move inside it to stay visible.
  @tracked fullscreenHost = this.#findFullscreenHost();

  #pruneTimer = setInterval(() => {
    this.now = Date.now();
  }, PRUNE_INTERVAL_MS);

  #syncFullscreenHost = () => {
    this.fullscreenHost = this.#findFullscreenHost();
  };

  constructor() {
    super(...arguments);
    document.addEventListener("fullscreenchange", this.#syncFullscreenHost);
    document.addEventListener(
      "webkitfullscreenchange",
      this.#syncFullscreenHost
    );
  }

  willDestroy() {
    super.willDestroy(...arguments);
    clearInterval(this.#pruneTimer);
    document.removeEventListener("fullscreenchange", this.#syncFullscreenHost);
    document.removeEventListener(
      "webkitfullscreenchange",
      this.#syncFullscreenHost
    );
  }

  get visibleCaptions() {
    const cutoff = this.now - LINE_TTL_MS;
    return this.liveWebrtc
      .captionsFor(this.args.room.id)
      .filter((caption) => caption.at > cutoff)
      .slice(-MAX_VISIBLE_LINES);
  }

  get showLoading() {
    return this.liveWebrtc.subtitlesLoading && !this.visibleCaptions.length;
  }

  get loadingLabel() {
    const percent = this.liveWebrtc.subtitlesProgress;
    if (percent !== null) {
      return i18n("live.subtitles.downloading", { percent });
    }
    return i18n("live.subtitles.loading");
  }

  #findFullscreenHost() {
    const element = fullscreenElement();
    return element?.matches(FULLSCREEN_HOSTS) ? element : null;
  }

  <template>
    {{#if this.liveWebrtc.subtitlesEnabled}}
      {{#if this.fullscreenHost}}
        {{#in-element this.fullscreenHost insertBefore=null}}
          <CaptionLines
            @captions={{this.visibleCaptions}}
            @fullscreen={{true}}
            @loadingLabel={{this.loadingLabel}}
            @showLoading={{this.showLoading}}
          />
        {{/in-element}}
      {{else}}
        <CaptionLines
          @captions={{this.visibleCaptions}}
          @loadingLabel={{this.loadingLabel}}
          @showLoading={{this.showLoading}}
        />
      {{/if}}
    {{/if}}
  </template>
}
