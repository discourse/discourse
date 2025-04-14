import { hash } from "@ember/helper";
import FilterComponent from "admin/components/report-filters/filter";
import ComboBox from "select-kit/components/combo-box";

export default class List extends FilterComponent {
  <template>
    <ComboBox
      @content={{this.filter.choices}}
      @value={{this.filter.default}}
      @onChange={{this.onChange}}
      @options={{hash
        allowAny=this.filter.allow_any
        autoInsertNoneItem=this.filter.auto_insert_none_item
        filterable=true
        none="admin.dashboard.report_filter_any"
        disabled=this.filter.disabled
      }}
    />
  </template>
}
