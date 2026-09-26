import Component from "@glimmer/component";
import { service } from "discourse/lib/service";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import ComposerService from "discourse/services/composer";

let load;

export default class LazyComposerContainer extends Component {
  @service(() => ComposerService) composer;

  get component() {
    return (load ??= import("discourse/components/composer-container"));
  }

  <template>
    {{#if this.composer.model}}
      <DAsyncContent @asyncData={{this.component}}>
        <:loading></:loading>
        <:content as |module|><module.default /></:content>
      </DAsyncContent>
    {{/if}}
  </template>
}
