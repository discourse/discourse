import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import bodyClass from "discourse/helpers/body-class";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";
import { TABLE_AI_LAYOUT, TABLE_LAYOUT } from "../services/gists";

export default class AiGistToggle extends Component {
  @service gists;

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
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  onSelect(optionId) {
    this.gists.setPreference(optionId, this.gists.isPm);
    this.dMenu.close();
  }

  <template>
    {{#if this.gists.showToggle}}
      {{bodyClass (concat "topic-list-layout-" this.gists.currentPreference)}}
      <DMenu
        @modalForMobile={{true}}
        @autofocus={{true}}
        @identifier="topic-list-layout"
        @onRegisterApi={{this.onRegisterApi}}
        @triggerClass="btn-default btn-icon"
      >
        <:trigger>
          {{icon this.currentButton.icon}}
        </:trigger>
        <:content>
          <DropdownMenu as |dropdown|>
            {{#each this.buttons as |button|}}
              <dropdown.item>
                <DButton
                  @label={{button.label}}
                  @icon={{button.icon}}
                  class="btn-transparent
                    {{if button.description '--with-description'}}
                    {{if (eq this.currentButton.id button.id) '--active'}}"
                  @action={{fn this.onSelect button.id}}
                >
                  {{#if button.description}}
                    <div class="btn__description">
                      {{i18n button.description}}
                    </div>
                  {{/if}}
                </DButton>
              </dropdown.item>
            {{/each}}
          </DropdownMenu>
        </:content>
      </DMenu>
    {{/if}}
  </template>
}
