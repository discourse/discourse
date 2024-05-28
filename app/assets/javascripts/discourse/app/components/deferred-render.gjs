import { tracked } from "@glimmer/tracking";
import Component from "@glimmer/component";
import loadingSpinner from "discourse/helpers/loading-spinner";
import runAfterFramePaint from "discourse/lib/after-frame-paint";

export default class DeferredRender extends Component {
  @tracked shouldRender = false;

  constructor(){
    super(...arguments);
    runAfterFramePaint(() => this.shouldRender = true);
  }

  <template>
    {{#if this.shouldRender}}
      {{yield}}
    {{else}}
      {{loadingSpinner}}
    {{/if}}
  </template>
}
