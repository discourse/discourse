import Component from "@glimmer/component";
import { designWizardState } from "discourse/lib/design-wizard-state";
import DAsyncContent from "discourse/ui-kit/d-async-content";

let load;

export default class LazyDesignWizardPanel extends Component {
  get component() {
    return (load ??= import("discourse/components/design-wizard-panel"));
  }

  <template>
    {{#if designWizardState.active}}
      <DAsyncContent @asyncData={{this.component}}>
        <:loading></:loading>
        <:content as |module|><module.default /></:content>
      </DAsyncContent>
    {{/if}}
  </template>
}
