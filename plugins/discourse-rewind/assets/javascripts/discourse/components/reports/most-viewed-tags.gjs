import { concat } from "@ember/helper";
import { i18n } from "discourse-i18n";

const MostViewedTags = <template>
  {{#if @report.data.length}}
    <div class="rewind-report-page --most-viewed-tags">
      <h2 class="rewind-report-title">{{i18n
          "discourse_rewind.reports.most_viewed_tags.title"
          count=@report.data.length
        }}</h2>
      <div class="rewind-report-container">
        {{#each @report.data as |data|}}
          <a class="folder-wrapper" href={{concat "/tag/" data.name}}>
            <span class="folder-tab"></span>
            <div class="rewind-card">
              <p
                class="most-viewed-tags__tag"
                href={{concat "/tag/" data.name}}
              >
                #{{data.name}}
              </p>
            </div>
            <span class="folder-bg"></span>
          </a>
        {{/each}}
      </div>
    </div>
  {{/if}}
</template>;

export default MostViewedTags;
