import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import {
  fieldShowDescription,
  propertyDescription,
} from "../../../lib/workflows/property-engine";

export default class NoticeControl extends Component {
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
    <@form.Alert @type="info">
      {{this.description}}
    </@form.Alert>
  </template>
}
