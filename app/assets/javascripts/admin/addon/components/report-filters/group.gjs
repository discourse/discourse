import { hash } from "@ember/helper";
import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import FilterComponent from "admin/components/report-filters/filter";
import ComboBox from "select-kit/components/combo-box";

@classNames("group-filter")
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
  </template>
}
