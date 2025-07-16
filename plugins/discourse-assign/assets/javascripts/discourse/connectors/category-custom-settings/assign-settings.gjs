import Component, { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";

@classNames("assign-settings")
export default class AssignSettings extends Component {
  @action
  onChangeSetting(event) {
    this.set(
      "outletArgs.category.custom_fields.enable_unassigned_filter",
      event.target.checked ? "true" : "false"
    );
  }

  <template>
    <h3>{{i18n "discourse_assign.assign.title"}}</h3>

    <section class="field">
      <div class="enable-accepted-answer">
        <label class="checkbox-label">
          <Input
            @type="checkbox"
            @checked={{readonly
              this.outletArgs.category.enable_unassigned_filter
            }}
            {{on "change" this.onChangeSetting}}
          />
          {{i18n "discourse_assign.add_unassigned_filter"}}
        </label>
      </div>
    </section>
  </template>
}
