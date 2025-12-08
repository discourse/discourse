import Component from "@glimmer/component";
import icon from "discourse/helpers/d-icon";
import number from "discourse/helpers/number";
import { i18n } from "discourse-i18n";

export default class FavoriteGifs extends Component {
  get favoriteGifs() {
    return this.args.report.data.favorite_gifs ?? [];
  }

  <template>
    {{#if this.favoriteGifs.length}}
      <div class="rewind-report-page --favorite-gifs">
        <h2 class="rewind-report-title">{{i18n
            "discourse_rewind.reports.favorite_gifs.title"
            count=this.favoriteGifs.length
          }}</h2>
        <div class="rewind-report-subtitle">{{i18n
            "discourse_rewind.reports.favorite_gifs.total_usage"
            count=@report.data.total_gif_usage
          }}</div>
        <div class="rewind-report-container">
          {{#each this.favoriteGifs as |gif idx|}}
            <div class="rewind-card scale">
              <div class="favorite-gifs__gif">
                <img
                  src={{gif.url}}
                  alt="GIF #{{idx}}"
                  class="favorite-gifs__image"
                  loading="lazy"
                />
                <div class="favorite-gifs__stats">
                  <span class="favorite-gifs__stat">
                    {{icon "repeat"}}
                    {{number gif.usage_count}}
                  </span>
                  <span class="favorite-gifs__stat">
                    {{icon "heart"}}
                    {{number gif.likes}}
                  </span>
                  <span class="favorite-gifs__stat">
                    {{icon "smile"}}
                    {{number gif.reactions}}
                  </span>
                </div>
              </div>
            </div>
          {{/each}}
        </div>
      </div>
    {{/if}}
  </template>
}
