import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import FilterComponent from "admin/components/report-filters/filter";

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
    <Input
      @type="checkbox"
      @checked={{this.checked}}
      {{on "click" this.onChange}}
    />
  </template>
}
