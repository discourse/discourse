import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import ComposerPickerContent from "discourse/components/composer-picker/content";
import DMenu from "discourse/float-kit/components/d-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class ComposerPicker extends Component {
  @tracked menu = null;

  get context() {
    return this.args.context ?? "topic";
  }

  get modalForMobile() {
    return this.args.modalForMobile ?? true;
  }

  @action
  onRegisterMenu(api) {
    this.menu = api;
  }

  <template>
    <DMenu
      @disabled={{@disabled}}
      @groupIdentifier="composer-picker"
      @identifier="composer-picker"
      @inline={{@inline}}
      @maxWidth={{500}}
      @modalForMobile={{this.modalForMobile}}
      @onClose={{@onClose}}
      @onRegisterApi={{this.onRegisterMenu}}
      @onShow={{@onShow}}
      @triggerClass={{@btnClass}}
    >
      <:trigger>
        {{dIcon "far-face-smile"}}&#8203;
      </:trigger>

      <:content>
        <ComposerPickerContent
          @close={{this.menu.close}}
          @context={{this.context}}
          @onSelect={{@onSelect}}
        />
      </:content>
    </DMenu>
  </template>
}
