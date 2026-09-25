import Component from "@glimmer/component";
import { service } from "@ember/service";
import DAsyncContent from "discourse/ui-kit/d-async-content";

let load;

export default class LazyDesignWizardPanel extends Component {
  @service designWizard;

  get component() {
    return (load ??= import("discourse/components/design-wizard-panel"));
  }

  <template>
    {{#if this.designWizard.active}}
      <DAsyncContent @asyncData={{this.component}}>
        <:loading></:loading>
        <:content as |module|><module.default /></:content>
      </DAsyncContent>
    {{/if}}
  </template>
}
