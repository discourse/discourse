import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { selectOption } from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";
import { TABLE_AI_LAYOUT, TABLE_LAYOUT } from "../services/gists.js";

export default class AiGistToggle extends Component {
  @service gists;
  @service siteSettings;

  get buttons() {
    return [
      {
        id: TABLE_LAYOUT,
        label: "discourse_ai.summarization.topic_list_layout.button.compact",
        icon: "discourse-table",
      },
      {
        id: TABLE_AI_LAYOUT,
        label: "discourse_ai.summarization.topic_list_layout.button.expanded",
        icon: "discourse-table-sparkles",
        description:
          "discourse_ai.summarization.topic_list_layout.button.expanded_description",
      },
    ];
  }

  /** The layouts as options, with their names and descriptions translated. */
  get layoutOptions() {
    return this.buttons.map((button) =>
      selectOption(button, {
        label: i18n(button.label),
        description: button.description && i18n(button.description),
      })
    );
  }

  get selectedOptionId() {
    return this.gists.currentPreference;
  }

  get currentButton() {
    const buttonPreference = this.buttons.find(
      (button) => button.id === this.selectedOptionId
    );
    return buttonPreference || this.buttons[0];
  }

  @action
  changeLayout(layout) {
    this.gists.setPreference(layout);
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  onSelect(optionId) {
    this.gists.setPreference(optionId);
    this.dMenu.close();
  }

  <template>
    {{#if this.gists.showToggle}}
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelect
          class="topic-list-layout-trigger"
          @clearMode="never"
          @contentClass="topic-list-layout-content"
          @icon={{this.currentButton.icon}}
          @iconField="icon"
          @iconOnly={{true}}
          @onChange={{this.changeLayout}}
          @options={{this.layoutOptions}}
          @selectedIcon="check"
          @showCaret={{false}}
          @texts={{hash ariaLabel=(i18n "discourse_ai.layout.label")}}
          @value={{this.currentButton.id}}
          @variant="static"
        />
      {{else}}
        <DMenu
          @autofocus={{true}}
          @identifier="topic-list-layout"
          @modalForMobile={{true}}
          @onRegisterApi={{this.onRegisterApi}}
          @triggerClass="btn-default btn-icon"
        >
          <:trigger>
            {{dIcon this.currentButton.icon}}
          </:trigger>
          <:content>
            <DDropdownMenu as |dropdown|>
              {{#each this.buttons as |button|}}
                <dropdown.item
                  class={{if (eq this.currentButton.id button.id) "--selected"}}
                >
                  <DButton
                    class="btn-transparent
                      {{if button.description '--with-description'}}"
                    @action={{fn this.onSelect button.id}}
                    @icon={{button.icon}}
                    @label={{button.label}}
                  >
                    {{#if button.description}}
                      <div class="btn__description">
                        {{i18n button.description}}
                      </div>
                    {{/if}}
                  </DButton>
                </dropdown.item>
              {{/each}}
            </DDropdownMenu>
          </:content>
        </DMenu>
      {{/if}}
    {{/if}}
  </template>
}
