import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

const MAX_VISIBLE_LINES = 3;
const LINE_TTL_MS = 10000;
const PRUNE_INTERVAL_MS = 1000;

export default class VoiceCaptionOverlay extends Component {
  @service voiceWebrtc;

  // Bumped on a timer so lines fall off the overlay once they go stale,
  // not only when a newer caption pushes them out.
  @tracked now = Date.now();

  #pruneTimer = setInterval(() => {
    this.now = Date.now();
  }, PRUNE_INTERVAL_MS);

  willDestroy() {
    super.willDestroy(...arguments);
    clearInterval(this.#pruneTimer);
  }

  get visibleCaptions() {
    const cutoff = this.now - LINE_TTL_MS;
    return this.voiceWebrtc
      .captionsFor(this.args.room.id)
      .filter((caption) => caption.at > cutoff)
      .slice(-MAX_VISIBLE_LINES);
  }

  get showLoading() {
    return this.voiceWebrtc.subtitlesLoading && !this.visibleCaptions.length;
  }

  get loadingLabel() {
    const percent = this.voiceWebrtc.subtitlesProgress;
    if (percent !== null) {
      return i18n("voice.subtitles.downloading", { percent });
    }
    return i18n("voice.subtitles.loading");
  }

  <template>
    {{#if this.voiceWebrtc.subtitlesEnabled}}
      <div aria-live="polite" class="voice-captions">
        {{#if this.showLoading}}
          <p class="voice-captions__line --loading">
            {{this.loadingLabel}}
          </p>
        {{else}}
          {{#each this.visibleCaptions key="id" as |caption|}}
            <p class="voice-captions__line {{if caption.interim '--interim'}}">
              {{#if caption.username}}
                <span
                  class="voice-captions__speaker"
                >{{caption.username}}</span>
              {{/if}}
              {{caption.text}}
            </p>
          {{/each}}
        {{/if}}
      </div>
    {{/if}}
  </template>
}
