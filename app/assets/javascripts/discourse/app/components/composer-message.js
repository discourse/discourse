import Component from "@ember/component";
import { getOwner } from "@ember/owner";
import { classNameBindings } from "@ember-decorators/component";
import discourseComputed from "discourse-common/utils/decorators";

@classNameBindings(":composer-popup", "message.extraClass")
export default class ComposerMessage extends Component {
  @discourseComputed("message.templateName")
  layout(templateName) {
    return getOwner(this).lookup(`template:composer/${templateName}`);
  }
}
