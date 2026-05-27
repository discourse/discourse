import { hash } from "@ember/helper";
import { computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import FilterComponent from "discourse/admin/components/report-filters/filter";
import ComboBox from "discourse/select-kit/components/combo-box";

@tagName("")
export default class Group extends FilterComponent {
  @computed
  get groupOptions() {
    return (this.site.groups || []).map((group) => {
      return { name: group["name"], value: group["id"] };
    });
  }

  @computed("filter.default")
  get groupId() {
    return this.filter.default ? parseInt(this.filter.default, 10) : null;
  }

  <template>
    <div class="group-filter" ...attributes>
      <ComboBox
        @valueProperty="value"
        @content={{this.groupOptions}}
        @value={{this.groupId}}
        @onChange={{this.onChange}}
        @options={{hash
          allowAny=this.filter.allow_any
          autoInsertNoneItem=this.filter.auto_insert_none_item
          filterable=true
          none="admin.dashboard.reports.groups"
        }}
      />
    </div>
  </template>
}
