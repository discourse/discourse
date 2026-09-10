import Component from "@glimmer/component";

export default class WorkflowSettingFieldKey extends Component {
  static shouldRender(args) {
    return Boolean(args.setting?.workflowSettingFieldId);
  }

  <template>
    <code
      class="workflows-setting-field-key"
    >{{@outletArgs.setting.setting}}</code>
  </template>
}
