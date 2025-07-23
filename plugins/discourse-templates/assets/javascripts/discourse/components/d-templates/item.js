import { action } from "@ember/object";
import Component from "@glimmer/component";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class DTemplatesItem extends Component {
  @action
  apply() {
    // run parametrized action to insert the template
    this.args.onInsertTemplate?.(this.args.template);

    ajax(`/discourse_templates/${this.args.template.id}/use`, {
      type: "POST",
    }).catch(popupAjaxError);
  }
}
