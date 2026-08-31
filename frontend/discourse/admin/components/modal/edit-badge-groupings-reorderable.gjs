import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { removeValueFromArray } from "discourse/lib/array-tools";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import { i18n } from "discourse-i18n";

/**
 * The reordering surface behind `enable_new_reordering_controls`. Mirrors
 * `modal/edit-badge-groupings.gjs`, over the shared reorderable list.
 *
 * TODO (ui-kit-reorderable-list-cleanup) rename this over `modal/edit-badge-groupings.gjs`
 * and drop the branch in admin-badges.gjs.
 */
export default class EditBadgeGroupings extends Component {
  @service dialog;
  @service store;

  @autoTrackedArray workingCopy = this.args.model.badgeGroupings.map((o) =>
    this.store.createRecord("badge-grouping", o)
  );

  groupingLabel = (grouping) => grouping.displayName || grouping.name;
  canDelete = (grouping) => !grouping.system;

  /**
   * Applies a committed move onto the staged working copy.
   *
   * @param {Object} move - The normalized move from the list.
   */
  @action
  handleMove(move) {
    this.workingCopy.splice(
      0,
      this.workingCopy.length,
      ...move.proposedToItems
    );
  }

  @action
  delete(item) {
    removeValueFromArray(this.workingCopy, item);
  }

  @action
  add() {
    const obj = this.store.createRecord("badge-grouping", {
      editing: true,
      name: i18n("admin.badges.badge_grouping"),
    });
    this.workingCopy.push(obj);
  }

  @action
  async saveAll() {
    const groupIds = this.workingCopy.map((i) => i.id || -1);
    const names = this.workingCopy.map((i) => i.name);
    try {
      const data = await ajax("/admin/badges/badge_groupings", {
        data: { ids: groupIds, names },
        type: "POST",
      });
      this.workingCopy.length = 0;
      data.badge_groupings.forEach((badgeGroup) => {
        this.workingCopy.push(
          this.store.createRecord("badge-grouping", {
            ...badgeGroup,
            editing: false,
          })
        );
      });
      this.args.model.updateGroupings(this.workingCopy);
      this.args.closeModal();
    } catch {
      this.dialog.alert(i18n("generic_error"));
    }
  }

  <template>
    <DModal
      @title={{i18n "admin.badges.badge_groupings.modal_title"}}
      @bodyClass="badge-groupings-modal"
      @closeModal={{@closeModal}}
    >
      <:body>
        <div class="badge-groupings">
          <DReorderableList
            @items={{this.workingCopy}}
            @label={{this.groupingLabel}}
            @onMove={{this.handleMove}}
            @onRemove={{this.delete}}
            @removable={{this.canDelete}}
            @controls="manual"
            @rowClass="badge-grouping-item"
            class="badge-groupings-list"
          >
            <:row as |wc controls|>
              <controls.handle />
              <div class="badge-grouping">
                {{#if wc.editing}}
                  <Input @value={{wc.name}} class="badge-grouping-name-input" />
                {{else}}
                  <span>{{wc.displayName}}</span>
                {{/if}}
              </div>
              <div class="actions">
                {{#if wc.editing}}
                  <DButton
                    @action={{fn (mut wc.editing) false}}
                    @icon="check"
                    class="btn-flat"
                  />
                {{else}}
                  {{#unless wc.system}}
                    <DButton
                      @action={{fn (mut wc.editing) true}}
                      @icon="pencil"
                      class="btn-flat"
                    />
                  {{/unless}}
                {{/if}}
                {{#if controls.remove}}
                  <controls.remove />
                {{/if}}
              </div>
            </:row>
          </DReorderableList>
        </div>
        <DButton
          @action={{this.add}}
          class="btn-default badge-groupings__add-grouping"
          @label="admin.badges.new"
        />
      </:body>
      <:footer>
        <DButton
          @action={{this.saveAll}}
          @label="admin.badges.save"
          class="btn-primary badge-groupings__save"
          @disabled={{this.submitDisabled}}
        />
        <DButton
          class="btn-flat d-modal-cancel"
          @action={{@closeModal}}
          @label="cancel"
        />
      </:footer>
    </DModal>
  </template>
}
