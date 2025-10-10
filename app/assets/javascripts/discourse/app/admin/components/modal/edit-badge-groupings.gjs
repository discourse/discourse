import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { A } from "@ember/array";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class EditBadgeGroupings extends Component {
  @service dialog;
  @service store;

  @tracked workingCopy = new TrackedArray();

  constructor() {
    super(...arguments);
    let copy = A();
    if (this.args.model.badgeGroupings) {
      this.args.model.badgeGroupings.forEach((o) =>
        copy.pushObject(this.store.createRecord("badge-grouping", o))
      );
    }
    this.workingCopy = copy;
  }

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
    this.workingCopy.removeObject(item);
  }

  @action
  add() {
    const obj = this.store.createRecord("badge-grouping", {
      editing: true,
      name: i18n("admin.badges.badge_grouping"),
    });
    this.workingCopy.pushObject(obj);
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
        this.workingCopy.pushObject(
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
    this.workingCopy.removeAt(index);
    this.workingCopy.insertAt(index + delta, item);
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
