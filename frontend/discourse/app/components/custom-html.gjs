import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { getCustomHTML } from "discourse/helpers/custom-html";

export default class CustomHtml extends Component {
  @service appEvents;

  get html() {
    return getCustomHTML(this.args.name);
  }

  @action
  didInsertElement() {
    if (this.args.triggerAppEvent) {
      this.appEvents.trigger(`inserted-custom-html:${this.args.name}`);
    }
  }

  @action
  willDestroyElement() {
    if (this.args.triggerAppEvent) {
      this.appEvents.trigger(`destroyed-custom-html:${this.args.name}`);
    }
  }

  <template>
    <div
      {{didInsert this.didInsertElement}}
      {{willDestroy this.willDestroyElement}}
      ...attributes
    >
      {{this.html}}
    </div>
  </template>
}
