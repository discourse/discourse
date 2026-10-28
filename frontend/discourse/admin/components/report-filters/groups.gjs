import { action } from "@ember/object";
import { service } from "@ember/service";
import CompareGroups from "discourse/admin/components/modal/compare-groups";
import CompareGroupsReorderable from "discourse/admin/components/modal/compare-groups-reorderable";
import FilterComponent from "discourse/admin/components/report-filters/filter";
import DButton from "discourse/ui-kit/d-button";

export default class Groups extends FilterComponent {
  @service modal;
  @service siteSettings;

  @action
  openCompareGroups() {
    // TODO (ui-kit-reorderable-list-cleanup) drop the branch and the legacy
    // component once the change ships.
    const Modal = this.siteSettings.enable_new_reordering_controls
      ? CompareGroupsReorderable
      : CompareGroups;

    this.modal.show(Modal, {
      model: {
        currentTokens: this.args.filter?.default ?? [],
        onApply: (tokens) =>
          this.args.applyFilter(this.args.filter.id, tokens.join(",")),
      },
    });
  }

  <template>
    <div ...attributes>
      <DButton
        class="btn-default report-filter-groups__button"
        @action={{this.openCompareGroups}}
        @icon="plus"
        @label="admin.dashboard.sections.engagement.whos_posting.add_group"
      />
    </div>
  </template>
}
