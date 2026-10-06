import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { reviewerApi } from "../../../../../lib/select-fixtures";

export default class ReviewersSelectExample extends Component {
  @tracked value = [101, 102, 103, 104, 105, 106, 999];

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
      @createUnresolvedItem={{this.createUnresolvedItem}}
      @identifier="sg-reviewers"
      @labelField="username"
      @load={{reviewerApi.search}}
      @multiple={{true}}
      @onChange={{this.update}}
      @placeholder={{i18n
        "styleguide.sections.select.pickers.reviewers.placeholder"
      }}
      @resolveValues={{reviewerApi.findMany}}
      @value={{this.value}}
    >
      <:selection as |person|>
        <span class="select-examples__row select-examples__row--glyph">
          {{#unless person.__unresolved}}
            <svg
              aria-hidden="true"
              class="select-examples__avatar --small"
              style={{person.avatarStyle}}
              viewBox="0 0 48 48"
            >
              <use
                href="/plugins/styleguide/images/avatar.svg#select-avatar"
              ></use>
            </svg>
          {{/unless}}
          {{person.username}}
        </span>
      </:selection>

      <:item as |person|>
        <span class="select-examples__row select-examples__row--identity">
          <svg
            aria-hidden="true"
            class="select-examples__avatar"
            style={{person.avatarStyle}}
            viewBox="0 0 48 48"
          >
            <use
              href="/plugins/styleguide/images/avatar.svg#select-avatar"
            ></use>
          </svg>
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
