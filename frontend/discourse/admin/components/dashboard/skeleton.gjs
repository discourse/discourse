import { i18n } from "discourse-i18n";

const KPIS = Array.from({ length: 4 });
const REPORT_CARDS = Array.from({ length: 4 });
const TRAFFIC_LIST_ROWS = Array.from({ length: 5 });
const METRICS = Array.from({ length: 3 });
const ENGAGEMENT_ACTIVITY_ROWS = Array.from({ length: 4 });

export default <template>
  <div
    class="db-skeleton --animation"
    role="status"
    aria-label={{i18n "admin.dashboard.loading"}}
  >
    <section class="db-skeleton__section db-skeleton__highlights">
      <div class="db-skeleton__section-header"></div>
      <div class="db-skeleton__kpi-row">
        {{#each KPIS}}
          <div class="db-skeleton__kpi">
            <div class="db-skeleton__kpi-value"></div>
            <div class="db-skeleton__kpi-label"></div>
            <div class="db-skeleton__kpi-delta"></div>
          </div>
        {{/each}}
      </div>
    </section>

    <section class="db-skeleton__section db-skeleton__reports">
      <div class="db-skeleton__section-header"></div>
      <div class="db-skeleton__report-grid">
        {{#each REPORT_CARDS}}
          <div class="db-skeleton__report-card">
            <div class="db-skeleton__report-card-header">
              <div class="db-skeleton__report-card-title"></div>
              <div class="db-skeleton__report-card-label"></div>
            </div>
            <div class="db-skeleton__report-card-chart"></div>
          </div>
        {{/each}}
      </div>
    </section>

    <section class="db-skeleton__section db-skeleton__traffic">
      <div class="db-skeleton__section-header"></div>
      <div class="db-skeleton__section-wrapper">
        <div class="db-skeleton__subheader">
          <div class="db-skeleton__subintro">
            <div class="db-skeleton__heading-line"></div>
            <div class="db-skeleton__text-line"></div>
            <div class="db-skeleton__text-line --short"></div>
          </div>
          <div class="db-skeleton__metric-row">
            {{#each METRICS}}
              <div class="db-skeleton__metric">
                <div class="db-skeleton__metric-number"></div>
                <div class="db-skeleton__metric-label"></div>
              </div>
            {{/each}}
          </div>
        </div>
        <div class="db-skeleton__chart"></div>
        <div class="db-skeleton__row">
          <div class="db-skeleton__row-block">
            <div class="db-skeleton__row-block-title"></div>
            <ul class="db-skeleton__list">
              {{#each TRAFFIC_LIST_ROWS}}
                <li class="db-skeleton__list-row">
                  <span class="db-skeleton__list-name"></span>
                  <span class="db-skeleton__list-value"></span>
                </li>
              {{/each}}
            </ul>
          </div>
          <div class="db-skeleton__row-block">
            <div class="db-skeleton__row-block-title"></div>
            <ul class="db-skeleton__list">
              {{#each TRAFFIC_LIST_ROWS}}
                <li class="db-skeleton__list-row">
                  <span class="db-skeleton__list-name"></span>
                  <span class="db-skeleton__list-value"></span>
                </li>
              {{/each}}
            </ul>
          </div>
        </div>
      </div>
    </section>

    <section class="db-skeleton__section db-skeleton__engagement">
      <div class="db-skeleton__section-header"></div>
      <div class="db-skeleton__section-wrapper">
        <div class="db-skeleton__subheader">
          <div class="db-skeleton__subintro">
            <div class="db-skeleton__heading-line"></div>
            <div class="db-skeleton__text-line"></div>
            <div class="db-skeleton__text-line --short"></div>
          </div>
          <div class="db-skeleton__metric-row">
            {{#each METRICS}}
              <div class="db-skeleton__metric">
                <div class="db-skeleton__metric-number"></div>
                <div class="db-skeleton__metric-label"></div>
              </div>
            {{/each}}
          </div>
        </div>
        <div class="db-skeleton__row">
          <div class="db-skeleton__row-block">
            <div class="db-skeleton__row-block-title"></div>
            <div class="db-skeleton__pipeline"></div>
          </div>
          <div class="db-skeleton__row-block">
            <div class="db-skeleton__row-block-title"></div>
            <div class="db-skeleton__pipeline"></div>
          </div>
        </div>
        <div class="db-skeleton__row">
          <div class="db-skeleton__row-block --full">
            <div class="db-skeleton__row-block-title"></div>
            <ul class="db-skeleton__list">
              {{#each ENGAGEMENT_ACTIVITY_ROWS}}
                <li class="db-skeleton__list-row">
                  <span class="db-skeleton__list-name"></span>
                  <span class="db-skeleton__list-value"></span>
                </li>
              {{/each}}
            </ul>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>
