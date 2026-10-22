import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class LovelaceChecklist extends Component {
  @tracked saving = false;
  @tracked _checklist;

  get checklist() {
    return this._checklist ?? this.args.model;
  }

  @action
  async moveItem(item, adding) {
    this.saving = true;
    const ids = this.checklist.items.map(({ id }) => id);
    try {
      this._checklist = await ajax("/lovelace/checklist.json", {
        type: "PUT",
        contentType: "application/json",
        data: JSON.stringify({
          item_ids: adding
            ? [...ids, item.id]
            : ids.filter((id) => id !== item.id),
        }),
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <div class="lovelace-checklist" ...attributes>
      <section
        aria-labelledby="lovelace-checklist-title"
        class="lovelace-checklist__selected"
      >
        <h2 id="lovelace-checklist-title">{{i18n "lovelace.checklist"}}</h2>
        <ul class="lovelace-checklist__items">
          {{#each this.checklist.items key="id" as |item|}}
            <li class="lovelace-checklist__item" data-item-id={{item.id}}>
              <h3>{{item.title}}</h3>
              <p>{{item.description}}</p>
              <a
                class="btn btn-primary"
                href={{item.url}}
              >{{item.button_text}}</a>
              {{#if @editing}}
                <DButton
                  @action={{fn this.moveItem item false}}
                  @disabled={{this.saving}}
                  @label="lovelace.remove"
                />
              {{/if}}
            </li>
          {{else}}
            <li>{{i18n "lovelace.empty"}}</li>
          {{/each}}
        </ul>
      </section>
      {{#if @editing}}
        <section
          aria-labelledby="lovelace-bank-title"
          class="lovelace-checklist__bank"
        >
          <h2 id="lovelace-bank-title">{{i18n "lovelace.bank"}}</h2>
          <p>{{i18n "lovelace.bank_description"}}</p>
          <ul class="lovelace-checklist__items">
            {{#each this.checklist.bank key="id" as |item|}}
              <li class="lovelace-checklist__item" data-item-id={{item.id}}>
                <h3>{{item.title}}</h3>
                <p>{{item.description}}</p>
                <p>{{item.button_text}}</p>
                <DButton
                  @action={{fn this.moveItem item true}}
                  @disabled={{this.saving}}
                  @label="lovelace.add"
                />
              </li>
            {{else}}
              <li>{{i18n "lovelace.bank_empty"}}</li>
            {{/each}}
          </ul>
        </section>
      {{/if}}
    </div>
  </template>
}
