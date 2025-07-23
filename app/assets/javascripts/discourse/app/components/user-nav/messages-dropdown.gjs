import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DMenu from "float-kit/components/d-menu";

export default class MessagesDropdown extends Component {
  get currentSelection() {
    return this.args.content.find((item) => item.id === this.args.value);
  }

  @action
  onRegisterApi(api) {
    this.menuApi = api;
  }

  @action
  openInbox(id) {
    this.args.onChange(id);
    this.menuApi.close();
  }

  <template>
    <DMenu
      @icon={{this.currentSelection.icon}}
      @label={{this.currentSelection.name}}
      @identifier="messages-dropdown"
      @onRegisterApi={{this.onRegisterApi}}
    >
      <:content>
        <DropdownMenu as |dropdown|>
          {{#each @content as |item|}}
            <dropdown.item>
              <DButton
                @translatedLabel={{item.name}}
                @icon={{item.icon}}
                class="btn-transparent"
                @action={{this.openInbox item.id}}
              />
            </dropdown.item>
          {{/each}}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
