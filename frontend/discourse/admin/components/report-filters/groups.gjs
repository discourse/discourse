import { action } from "@ember/object";
import { service } from "@ember/service";
import CompareGroups from "discourse/admin/components/modal/compare-groups";
import FilterComponent from "discourse/admin/components/report-filters/filter";
import DButton from "discourse/ui-kit/d-button";

export default class Groups extends FilterComponent {
  @service modal;

  @action
  openCompareGroups() {
    this.modal.show(CompareGroups, {
      model: {
        currentTokens: this.filter?.default ?? [],
        onApply: (tokens) => this.applyFilter(this.filter.id, tokens.join(",")),
      },
    });
  }

  <template>
    <DButton
      class="btn-default report-filter-groups__button"
      @action={{this.openCompareGroups}}
      @icon="plus"
      @label="admin.dashboard.sections.engagement.whos_posting.add_group"
    />
  </template>
}
