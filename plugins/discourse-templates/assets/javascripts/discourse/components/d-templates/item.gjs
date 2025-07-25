import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ItemContent from "./item-content";

export default class DTemplatesItem extends Component {
  @action
  apply() {
    // run parametrized action to insert the template
    this.args.onInsertTemplate?.(this.args.template);

    ajax(`/discourse_templates/${this.args.template.id}/use`, {
      type: "POST",
    }).catch(popupAjaxError);
  }

  <template>
    <details class="template-item" id="template-item-{{@template.id}}">
      <summary class="template-item-title">
        <div class="template-item-title-text">{{@template.title}}</div>

        <div class="actions">
          <DButton
            @action={{this.apply}}
            @icon="far-clipboard"
            class="templates-apply"
          />
        </div>
      </summary>

      <ItemContent @template={{@template}} />
    </details>
  </template>
}
