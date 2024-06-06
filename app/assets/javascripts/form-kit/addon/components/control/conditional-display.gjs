import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import uniqueId from "discourse/helpers/unique-id";
import FkControlConditionalDisplayOption from "./conditional-display/option";

export default class FkControlConditionalDisplay extends Component {
  @tracked options = new TrackedArray();

  name = uniqueId();

  @action
  registerOption(id, label) {
    this.options.pushObject({ id, label });
  }

  <template>
    <div class="d-form-conditional-display">
      {{#each this.options as |option|}}
        <div class="d-form-conditional-display__option">
          <label>{{option.label}}
            <input type="radio" name={{this.name}} value={{option.id}} />
          </label>
        </div>
      {{/each}}

      {{yield
        (hash
          Option=(component
            FkControlConditionalDisplayOption
            id=(uniqueId)
            registerOption=this.registerOption
          )
        )
      }}
    </div>
  </template>
}
