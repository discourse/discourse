import { Input } from "@ember/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import FilterComponent from "discourse/admin/components/report-filters/filter";
import { i18n } from "discourse-i18n";

export default class Bool extends FilterComponent {
  checked = false;

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);
    this.set("checked", !!this.filter.default);
  }

  @action
  onChange() {
    this.applyFilter(this.filter.id, !this.checked || undefined);
  }

  <template>
    <label class="chart__filter-label checkbox-label">
      <Input
        @type="checkbox"
        @checked={{this.checked}}
        {{on "click" this.onChange}}
      />
      {{i18n
        (concat "admin.dashboard.reports.filters." this.filter.id ".label")
      }}
    </label>
  </template>
}
