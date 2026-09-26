import Component from "@glimmer/component";
import { composerState } from "discourse/lib/composer/state";
import DAsyncContent from "discourse/ui-kit/d-async-content";

let load;

export default class LazyComposerContainer extends Component {
  get component() {
    return (load ??= import("discourse/components/composer-container"));
  }

  <template>
    {{#if composerState.model}}
      <DAsyncContent @asyncData={{this.component}}>
        <:loading></:loading>
        <:content as |module|><module.default /></:content>
      </DAsyncContent>
    {{/if}}
  </template>
}
