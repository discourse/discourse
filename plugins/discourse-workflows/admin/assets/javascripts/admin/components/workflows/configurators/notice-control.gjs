import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import {
  fieldShowDescription,
  propertyDescription,
  propertyDescriptionIsLiteral,
} from "../../../lib/workflows/property-engine";

export default class NoticeControl extends Component {
  get description() {
    if (!fieldShowDescription(this.args.schema)) {
      return undefined;
    }
    const description = propertyDescription(
      this.args.nodeDefinition,
      this.args.fieldName,
      this.args.schema
    );
    if (!description) {
      return undefined;
    }

    return propertyDescriptionIsLiteral(
      this.args.nodeDefinition,
      this.args.fieldName,
      this.args.schema
    )
      ? description
      : trustHTML(description);
  }

  <template>
    <@form.Alert @type="info">
      {{this.description}}
    </@form.Alert>
  </template>
}
