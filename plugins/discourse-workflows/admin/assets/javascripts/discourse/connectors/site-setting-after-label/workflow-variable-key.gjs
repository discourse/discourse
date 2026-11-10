import Component from "@glimmer/component";

export default class WorkflowVariableKey extends Component {
  static shouldRender(args) {
    return Boolean(args.setting?.workflowVariableId);
  }

  <template>
    <code class="workflows-variable-key">{{@outletArgs.setting.setting}}</code>
  </template>
}
