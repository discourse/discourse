import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

const SKELETON_METRICS = Array.from({ length: 4 });
const SKELETON_BREAKDOWNS = Array.from({ length: 3 });
const SKELETON_ROWS = Array.from({ length: 8 });

function replaceSplash() {
  document.querySelector("#d-splash")?.remove();
}

export default <template>
  <div
    class="site-traffic-explorer admin-config-page"
    {{didInsert replaceSplash}}
  >
    <DPageHeader
      @collapseActionsOnMobile={{false}}
      @hideTabs={{true}}
      @titleLabel={{i18n "admin.site_traffic_explorer.title"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
        <DBreadcrumbsItem
          @label={{i18n "admin.dashboard.title"}}
          @path="/admin"
        />
        <DBreadcrumbsItem
          @label={{i18n "admin.site_traffic_explorer.title"}}
          @path="/admin/dashboard/site-traffic-explorer"
        />
      </:breadcrumbs>
    </DPageHeader>

    <div class="admin-container site-traffic-explorer__content">
      <div
        aria-label={{i18n "admin.site_traffic_explorer.loading"}}
        class="db-skeleton --animation site-traffic-explorer__skeleton"
        data-test-site-traffic-skeleton
        role="status"
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
