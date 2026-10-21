import { Input } from "@ember/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import FilterComponent from "discourse/admin/components/report-filters/filter";
import { resettableTracked } from "discourse/lib/tracked-tools";
import { i18n } from "discourse-i18n";

export default class Bool extends FilterComponent {
  @resettableTracked checked = !!this.args.filter.default;

  @action
  onChange() {
    this.args.applyFilter(this.args.filter.id, !this.checked || undefined);
  }

  <template>
    <div ...attributes>
      <label class="chart__filter-label checkbox-label">
        <Input
          @checked={{this.checked}}
          @type="checkbox"
          {{on "click" this.onChange}}
        />
        {{i18n (concat "admin.dashboard.reports.filters." @filter.id ".label")}}
      </label>
    </div>
  </template>
}
