import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class WorkflowsFormFullPage extends Component {
  @service router;

  get isFormRoute() {
    return this.router.currentRouteName === "workflows-form";
  }

  <template>
    {{#if this.isFormRoute}}
      <div class="workflows-form-page">
        {{outlet}}
      </div>
    {{else}}
      {{yield}}
    {{/if}}
  </template>
}
