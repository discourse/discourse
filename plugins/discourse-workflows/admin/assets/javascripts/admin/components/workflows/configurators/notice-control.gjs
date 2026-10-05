import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import {
  fieldShowDescription,
  propertyDescription,
} from "../../../lib/workflows/property-engine";

export default class NoticeControl extends Component {
  get controlOptions() {
    return this.args.schema?.control_options || {};
  }

  get alertType() {
    return this.controlOptions.alert_type || "info";
  }

  get isShown() {
    const rule = this.controlOptions.show_for_option;
    if (!rule) {
      return true;
    }

    const target = this.args.nodeDefinition?.properties?.[rule.field];
    const method = target?.type_options?.load_options_method;
    const key = target?.control_options?.value_property || "id";
    const value = this.args.configuration?.[rule.field];
    const option = (this.args.metadata?.[method] || []).find(
      (candidate) => String(candidate[key]) === String(value)
    );

    return option?.[rule.property] === rule.value;
  }

  get description() {
    if (!fieldShowDescription(this.args.schema)) {
      return undefined;
    }
    const desc = propertyDescription(
      this.args.nodeDefinition,
      this.args.fieldName
    );
    return desc ? trustHTML(desc) : undefined;
  }

  <template>
    {{#if this.isShown}}
      <@form.Alert @type={{this.alertType}}>
        {{this.description}}
      </@form.Alert>
    {{/if}}
  </template>
}
