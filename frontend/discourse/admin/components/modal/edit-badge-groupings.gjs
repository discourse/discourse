import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { removeValueFromArray } from "discourse/lib/array-tools";
import { trackedArray } from "discourse/lib/tracked-tools";
import { i18n } from "discourse-i18n";

export default class EditBadgeGroupings extends Component {
  @service dialog;
  @service store;

  @trackedArray workingCopy = this.args.model.badgeGroupings.map((o) =>
    this.store.createRecord("badge-grouping", o)
  );

  @action
  up(item) {
    this.moveItem(item, -1);
  }

  @action
  down(item) {
    this.moveItem(item, 1);
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
      this.workingCopy.clear();
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

  moveItem(item, delta) {
    const index = this.workingCopy.indexOf(item);
    if (index + delta < 0 || index + delta >= this.workingCopy.length) {
      return;
    }
    this.workingCopy.splice(index, 1); // remove the item from the old position
    this.workingCopy.splice(index + delta, 0, item); // insert it in the new position
  }

  <template>
    <DModal
      @title={{i18n "admin.badges.badge_groupings.modal_title"}}
      @bodyClass="badge-groupings-modal"
      @closeModal={{@closeModal}}
    >
      <:body>
        <div class="badge-groupings">
          <ul class="badge-groupings-list">
            {{#each this.workingCopy as |wc|}}
              <li class="badge-grouping-item">
                <div class="badge-grouping">
                  {{#if wc.editing}}
                    <Input
                      @value={{wc.name}}
                      class="badge-grouping-name-input"
                    />
                  {{else}}
                    <span>{{wc.displayName}}</span>
                  {{/if}}
                </div>
                <div class="actions">
                  {{#if wc.editing}}
                    <DButton
                      @action={{fn (mut wc.editing) false}}
                      @icon="check"
                    />
                  {{else}}
                    <DButton
                      @action={{fn (mut wc.editing) true}}
                      @disabled={{wc.system}}
                      @icon="pencil"
                    />
                  {{/if}}
                  <DButton @action={{fn this.up wc}} @icon="chevron-up" />
                  <DButton @action={{fn this.down wc}} @icon="chevron-down" />
                  <DButton
                    @action={{fn this.delete wc}}
                    @disabled={{wc.system}}
                    @icon="xmark"
                  />
                </div>
              </li>
            {{/each}}
          </ul>
        </div>
        <DButton
          @action={{this.add}}
          class="badge-groupings__add-grouping"
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
