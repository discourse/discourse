import { action } from "@ember/object";
import { service } from "discourse/lib/service";
import FilterComponent from "discourse/admin/components/report-filters/filter";
import DButton from "discourse/ui-kit/d-button";
import ModalService from "discourse/services/modal";

export default class Groups extends FilterComponent {
  @service(() => ModalService) modal;

  @action
  openCompareGroups() {
    this.modal.show(
      () => import("discourse/admin/components/modal/compare-groups"),
      {
        model: {
          currentTokens: this.filter?.default ?? [],
          onApply: (tokens) =>
            this.applyFilter(this.filter.id, tokens.join(",")),
        },
      }
    );
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
