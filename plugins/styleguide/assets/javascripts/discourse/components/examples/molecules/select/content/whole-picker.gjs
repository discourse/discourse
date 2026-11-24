import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import {
  TEAM_MEMBERS,
  teamLabels,
} from "../../../../../lib/select-fixtures.js";

export default class WholePickerSelectExample extends Component {
  @tracked value = [];

  @action
  groupHeader(key) {
    return teamLabels()[key] ?? key;
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @groupBy="team"
      @groupHeader={{this.groupHeader}}
      @identifier="sg-content-picker"
      @labelField="name"
      @multiple={{true}}
      @onChange={{this.onChange}}
      @options={{TEAM_MEMBERS}}
      @texts={{hash
        placeholder=(i18n
          "styleguide.sections.select.content.picker_placeholder"
        )
      }}
      @value={{this.value}}
    >
      <:groupHeader as |option|>
        <span class="select-examples__group-header">
          {{dIcon "users"}}
          {{option.label}}
        </span>
      </:groupHeader>
      <:option as |option|>
        {{#let option.record as |person|}}
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
              <span class="select-examples__primary">{{option.label}}</span>
              <span class="select-examples__secondary">
                {{if person.status person.status person.title}}
              </span>
            </span>
          </span>
        {{/let}}
      </:option>
      <:selection as |option|>
        <span class="select-examples__row select-examples__row--glyph">
          <svg
            aria-hidden="true"
            class="select-examples__avatar --small"
            style={{option.record.avatarStyle}}
            viewBox="0 0 48 48"
          >
            <use
              href="/plugins/styleguide/images/avatar.svg#select-avatar"
            ></use>
          </svg>
          {{option.label}}
        </span>
      </:selection>
      <:footer as |state|>
        <span class="select-examples__footer-count">
          {{i18n
            "styleguide.sections.select.content.picker_selected"
            count=state.value.length
          }}
        </span>
      </:footer>
    </DSelect>
  </template>
}
