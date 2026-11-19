import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { getCustomHTML } from "discourse/helpers/custom-html";
import type AppEventsService from "discourse/services/app-events";

interface DCustomHtmlSignature {
  Args: {
    /** The key the custom HTML was registered under. */
    name: string;

    /**
     * Whether to trigger the `inserted-custom-html:<name>` and
     * `destroyed-custom-html:<name>` app events as the HTML enters and leaves the page.
     */
    triggerAppEvent?: boolean;
  };

  Element: HTMLDivElement;
}

export default class DCustomHtml extends Component<DCustomHtmlSignature> {
  @service declare appEvents: AppEventsService;

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
      ...attributes
      {{didInsert this.didInsertElement}}
      {{willDestroy this.willDestroyElement}}
    >
      {{this.html}}
    </div>
  </template>
}
