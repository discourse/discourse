import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import DButton from "discourse/components/d-button";
import withEventValue from "discourse/helpers/with-event-value";
import { resettableTracked } from "discourse/lib/tracked-tools";
import { i18n } from "discourse-i18n";

// args: action, labelKey, checked, modelId
export default class InlineEditCheckbox extends Component {
  @resettableTracked value = this.args.checked;

  get changed() {
    return !!this.args.checked !== !!this.value;
  }

  @action
  reset() {
    this.value = this.args.checked;
  }

  <template>
    <div {{didUpdate this.reset @modelId}} class="inline-edit">
      <label class="checkbox-label">
        <input
          {{on
            "change"
            (withEventValue (fn (mut this.value)) "target.checked")
          }}
          checked={{this.value}}
          type="checkbox"
        />
        {{i18n @labelKey}}
      </label>

      {{#if this.changed}}
        <DButton
          @action={{fn @action this.value}}
          @icon="check"
          class="btn-success btn-small submit-edit"
        />
        <DButton
          @action={{this.reset}}
          @icon="xmark"
          class="btn-danger btn-small cancel-edit"
        />
      {{/if}}
    </div>
  </template>
}
