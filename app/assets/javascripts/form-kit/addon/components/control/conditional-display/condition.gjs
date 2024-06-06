import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";

export default class FkControlConditionalDisplayOption extends Component {
  <template>
    <div class="d-form-conditional-display__condition">
      {{yield}}
      <input
        type="radio"
        name={{@id}}
        value={{@name}}
        checked={{@active}}
        {{on "change" (fn @setCondition @name)}}
      />
    </div>
  </template>
}
