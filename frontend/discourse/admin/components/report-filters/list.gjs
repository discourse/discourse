import { hash } from "@ember/helper";
import FilterComponent from "discourse/admin/components/report-filters/filter";
import ComboBox from "discourse/select-kit/components/combo-box";

export default class List extends FilterComponent {
  <template>
    <div ...attributes>
      <ComboBox
        @content={{@filter.choices}}
        @onChange={{this.onChange}}
        @options={{hash
          allowAny=@filter.allow_any
          autoInsertNoneItem=@filter.auto_insert_none_item
          filterable=true
          none="admin.dashboard.report_filter_any"
          disabled=@filter.disabled
        }}
        @value={{@filter.default}}
      />
    </div>
  </template>
}
