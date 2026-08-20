import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

const SKELETON_METRICS = Array.from({ length: 4 });
const SKELETON_BREAKDOWNS = Array.from({ length: 3 });
const SKELETON_ROWS = Array.from({ length: 8 });

export default <template>
  <div class="site-traffic-explorer admin-config-page">
    <DPageHeader
      @titleLabel={{i18n "admin.site_traffic_explorer.title"}}
      @hideTabs={{true}}
      @collapseActionsOnMobile={{false}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin"
          @label={{i18n "admin.dashboard.title"}}
        />
        <DBreadcrumbsItem
          @path="/admin/dashboard/site-traffic-explorer"
          @label={{i18n "admin.site_traffic_explorer.title"}}
        />
      </:breadcrumbs>
    </DPageHeader>

    <div class="admin-container site-traffic-explorer__content">
      <div
        class="db-skeleton --animation site-traffic-explorer__skeleton"
        role="status"
        aria-label={{i18n "admin.site_traffic_explorer.loading"}}
        data-test-site-traffic-skeleton
      >
        <div class="db-skeleton__section-wrapper">
          <div class="db-skeleton__subheader">
            <div class="db-skeleton__subintro">
              <div class="db-skeleton__heading-line"></div>
            </div>
            <div class="db-skeleton__metric-row">
              {{#each SKELETON_METRICS}}
                <div class="db-skeleton__metric">
                  <div class="db-skeleton__metric-number"></div>
                  <div class="db-skeleton__metric-label"></div>
                </div>
              {{/each}}
            </div>
          </div>
          <div class="db-skeleton__chart"></div>
          <div class="db-skeleton__row">
            {{#each SKELETON_BREAKDOWNS}}
              <div class="db-skeleton__row-block">
                <div class="db-skeleton__row-block-title"></div>
                <ul class="db-skeleton__list">
                  {{#each SKELETON_ROWS}}
                    <li class="db-skeleton__list-row">
                      <span class="db-skeleton__list-name"></span>
                      <span class="db-skeleton__list-value"></span>
                    </li>
                  {{/each}}
                </ul>
              </div>
            {{/each}}
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
