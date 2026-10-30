import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DSelectList from "discourse/ui-kit/select/d-select-list";
import { i18n } from "discourse-i18n";
import { delay, TAGS } from "../../../../../lib/select-fixtures.js";

/** Two independent tag lists share a panel and its dismissal. */
export default class ListSelectExample extends Component {
  @tracked exclude = false;
  @tracked excluded = [];
  @tracked included = ["design-system"];

  data = { exclude: false };
  tags = TAGS;

  @action
  async load(filter, { signal }) {
    await delay(signal, 800);
    return TAGS.filter((tag) => tag.label.includes(filter.toLowerCase()));
  }

  @action
  updateIncluded(value) {
    this.included = value;
  }

  @action
  updateExcluded(value) {
    this.excluded = value;
  }

  /** Unchecking also drops the excluded tags, so a hidden list never narrows the results. */
  @action
  async setExclude(value, { name, set }) {
    await set(name, value);
    this.exclude = value;
    if (!value) {
      this.excluded = [];
    }
  }

  @action
  async clear(set) {
    this.included = [];
    await this.setExclude(false, { name: "exclude", set });
  }

  <template>
    <DMenu
      @contentClass="select-examples__list-panel"
      @identifier="sg-select-list"
      @inlineTabOrder={{true}}
      @label={{i18n "styleguide.sections.select.list_open"}}
      @trapTab={{false}}
      @triggerClass="btn-default"
    >
      <:content>
        <Form @data={{this.data}} as |form|>
          <DSelectList
            class="select-examples__tag-list --include"
            @ariaLabel={{i18n "styleguide.sections.select.list_include"}}
            @hideSelected={{true}}
            @identifier="sg-list-include"
            @labelField="label"
            @load={{this.load}}
            @onChange={{this.updateIncluded}}
            @searchPlaceholder={{i18n "styleguide.sections.select.list_search"}}
            @value={{this.included}}
            @valueField="slug"
            @valueItems={{this.tags}}
            @virtualized={{false}}
          >
            <:listHeader as |state|>
              {{#unless state.query}}
                <span>
                  {{~i18n "styleguide.sections.select.list_suggested"~}}
                </span>
              {{/unless}}
            </:listHeader>
          </DSelectList>
          <form.Field
            @name="exclude"
            @onSet={{this.setExclude}}
            @title={{i18n "styleguide.sections.select.list_exclude"}}
            @type="checkbox"
            as |field|
          >
            <field.Control />
          </form.Field>
          {{#if this.exclude}}
            <DSelectList
              class="select-examples__tag-list --exclude"
              @ariaLabel={{i18n "styleguide.sections.select.list_exclude"}}
              @hideSelected={{true}}
              @identifier="sg-list-exclude"
              @labelField="label"
              @load={{this.load}}
              @onChange={{this.updateExcluded}}
              @searchPlaceholder={{i18n
                "styleguide.sections.select.list_search"
              }}
              @value={{this.excluded}}
              @valueField="slug"
              @valueItems={{this.tags}}
              @virtualized={{false}}
            />
          {{/if}}
          <DButton
            class="btn-flat select-examples__list-clear"
            @action={{fn this.clear form.set}}
            @label="styleguide.sections.select.list_clear"
          />
        </Form>
      </:content>
    </DMenu>
  </template>
}
