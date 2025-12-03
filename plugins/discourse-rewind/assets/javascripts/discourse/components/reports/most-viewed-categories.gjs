import { concat } from "@ember/helper";
import { i18n } from "discourse-i18n";

const MostViewedCategories = <template>
  {{#if @report.data.length}}
    <div class="rewind-report-page --most-viewed-categories">
      <h2 class="rewind-report-title">
        {{i18n
          "discourse_rewind.reports.most_viewed_categories.title"
          count=@report.data.length
        }}
      </h2>
      <div class="rewind-report-container">
        {{#each @report.data as |data|}}
          <a class="folder-wrapper" href={{concat "/c/-/" data.category_id}}>
            <span class="folder-tab"></span>
            <div class="rewind-card">
              <p class="most-viewed-categories__category">#{{data.name}}</p>
            </div>
            <span class="folder-bg"></span>
          </a>
        {{/each}}
      </div>
    </div>
  {{/if}}
</template>;

export default MostViewedCategories;
