import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import ComposerPickerContent from "discourse/components/composer-picker/content";
import DMenu from "discourse/float-kit/components/d-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class ComposerPicker extends Component {
  @tracked menu = null;

  @action
  onRegisterMenu(api) {
    this.menu = api;
  }

  get icon() {
    return this.args.icon === undefined ? "far-face-smile" : this.args.icon;
  }

  get context() {
    return this.args.context ?? "topic";
  }

  get modalForMobile() {
    return this.args.modalForMobile ?? true;
  }

  <template>
    <DMenu
      @triggerClass={{@btnClass}}
      @onRegisterApi={{this.onRegisterMenu}}
      @identifier="composer-picker"
      @groupIdentifier="composer-picker"
      @modalForMobile={{this.modalForMobile}}
      @maxWidth={{500}}
      @onShow={{@onShow}}
      @onClose={{@onClose}}
      @inline={{@inline}}
      @disabled={{@disabled}}
    >
      <:trigger>
        {{dIcon this.icon}}&#8203;
      </:trigger>

      <:content>
        <ComposerPickerContent
          @close={{this.menu.close}}
          @onSelect={{@onSelect}}
          @context={{this.context}}
        />
      </:content>
    </DMenu>
  </template>
}
