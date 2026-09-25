import Component from "@glimmer/component";
import { service } from "@ember/service";
import DAsyncContent from "discourse/ui-kit/d-async-content";

let load;

export default class LazyComposerContainer extends Component {
  @service composer;

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
