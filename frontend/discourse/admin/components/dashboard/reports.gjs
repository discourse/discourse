import Component from "@glimmer/component";
import { action } from "@ember/object";
import DashboardSection from "discourse/admin/components/dashboard/section";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class DashboardReports extends Component {
  @action
  openReportsConfig() {
    // eslint-disable-next-line no-console
    console.log("Reports header action clicked", {
      startDate: this.args.startDate,
      endDate: this.args.endDate,
    });
  }

  <template>
    <DashboardSection
      @title={{i18n "admin.dashboard.sections.reports.title"}}
      @bordered={{false}}
      @layout="grid"
      @headerActionIcon="gear"
      @headerAction={{this.openReportsConfig}}
      @startDate={{@startDate}}
      @endDate={{@endDate}}
    >
      <div class="db-report__card">
        <div class="db-report__header">
          <a class="db-report__name">Pageviews by type</a>
          <div class="db-report__label">Standard</div>
          <DButton
            @icon="xmark"
            @translatedAriaLabel="Remove"
            class="db-report__remove btn-transparent btn-small"
          />
        </div>
        <div class="db-report__chart">PLACEHOLDER</div>
      </div>

      <div class="db-report__card">
        <div class="db-report__header">
          <a class="db-report__name">New signups</a>
          <div class="db-report__label --data-explorer">Data Explorer</div>
          <DButton
            @icon="xmark"
            @translatedAriaLabel="Remove"
            class="db-report__remove btn-transparent btn-small"
          />
        </div>
        <div class="db-report__chart">PLACEHOLDER</div>
      </div>

      <div class="db-report__card">
        <div class="db-report__header">
          <a class="db-report__name">Active users</a>
          <div class="db-report__label">Standard</div>
          <DButton
            @icon="xmark"
            @translatedAriaLabel="Remove"
            class="db-report__remove btn-transparent btn-small"
          />
        </div>
        <div class="db-report__chart">PLACEHOLDER</div>
      </div>

      <div class="db-report__card">
        <div class="db-report__header">
          <a class="db-report__name">Active users</a>
          <div class="db-report__label">Standard</div>
          <DButton
            @icon="xmark"
            @translatedAriaLabel="Remove"
            class="db-report__remove btn-transparent btn-small"
          />
        </div>
        <div class="db-report__chart">PLACEHOLDER</div>
      </div>

      <button class="db-report__add-report" aria-label="Add report"><span>{{icon
            "plus"
          }}
          Add report</span></button>
    </DashboardSection>

    <aside class="db-upgrade-banner">
      <p>Upgrade to pin Data Explorer queries as charts to track anything
        specific to your community.</p>
      <DButton @display="link" @suffixIcon="arrow-right">Upgrade</DButton>
    </aside>
  </template>
}
