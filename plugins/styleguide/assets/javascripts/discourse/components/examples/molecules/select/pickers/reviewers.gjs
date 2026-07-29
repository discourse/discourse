import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import {
  delay,
  PEOPLE,
  REVIEWER_IDS,
} from "../../../../../lib/select-fixtures";

export default class ReviewersSelectExample extends Component {
  @tracked value = REVIEWER_IDS;

  @action
  async load(filter, { signal }) {
    await delay(signal, 650);
    const normalizedFilter = filter.toLowerCase();
    return PEOPLE.filter((person) =>
      `${person.name} ${person.username} ${person.title ?? ""}`
        .toLowerCase()
        .includes(normalizedFilter)
    );
  }

  @action
  async resolveValues(values, { signal }) {
    await delay(signal, 500);
    return PEOPLE.filter((person) => values.includes(person.id));
  }

  @action
  createUnresolvedItem(value) {
    return {
      id: value,
      name: i18n("styleguide.sections.select.pickers.reviewers.deleted_name"),
      title: i18n(
        "styleguide.sections.select.pickers.reviewers.deleted_description"
      ),
      username: i18n(
        "styleguide.sections.select.pickers.reviewers.deleted_username"
      ),
    };
  }

  @action
  update(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-reviewers"
      @load={{this.load}}
      @value={{this.value}}
      @onChange={{this.update}}
      @multiple={{true}}
      @resolveValues={{this.resolveValues}}
      @createUnresolvedItem={{this.createUnresolvedItem}}
      @labelField="username"
      @placeholder={{i18n
        "styleguide.sections.select.pickers.reviewers.placeholder"
      }}
    >
      <:selection as |person|>
        <span class="select-examples__row select-examples__row--glyph">
          {{#unless person.__unresolved}}
            <img
              class="select-examples__avatar --small"
              src={{person.avatar}}
              alt=""
            />
          {{/unless}}
          {{person.username}}
        </span>
      </:selection>

      <:item as |person|>
        <span class="select-examples__row select-examples__row--identity">
          <img class="select-examples__avatar" src={{person.avatar}} alt="" />
          <span class="select-examples__details">
            <span class="select-examples__primary">{{person.name}}</span>
            <span class="select-examples__secondary">
              @{{person.username}}{{#if person.title}}
                ·
                {{person.title}}
              {{/if}}
            </span>
          </span>
        </span>
      </:item>
    </DSelect>
  </template>
}
