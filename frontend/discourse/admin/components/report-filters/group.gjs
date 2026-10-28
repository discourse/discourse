import { hash } from "@ember/helper";
import { service } from "@ember/service";
import FilterComponent from "discourse/admin/components/report-filters/filter";
import ComboBox from "discourse/select-kit/components/combo-box";

export default class Group extends FilterComponent {
  @service site;

  get groupOptions() {
    return (this.site.groups || []).map((group) => {
      return { name: group["name"], value: group["id"] };
    });
  }

  get groupId() {
    return this.args.filter.default
      ? parseInt(this.args.filter.default, 10)
      : null;
  }

  <template>
    <div class="group-filter" ...attributes>
      <ComboBox
        @content={{this.groupOptions}}
        @onChange={{this.onChange}}
        @options={{hash
          allowAny=@filter.allow_any
          autoInsertNoneItem=@filter.auto_insert_none_item
          filterable=true
          none="admin.dashboard.reports.groups"
        }}
        @value={{this.groupId}}
        @valueProperty="value"
      />
    </div>
  </template>
}
