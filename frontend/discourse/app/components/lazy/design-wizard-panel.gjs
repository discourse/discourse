import Component from "@glimmer/component";
import { service } from "discourse/lib/service";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DesignWizardService from "discourse/services/design-wizard";

let load;

export default class LazyDesignWizardPanel extends Component {
  @service(() => DesignWizardService) designWizard;

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
