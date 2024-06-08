import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { eq } from "truth-helpers";

export default class FkControlConditionalContentOption extends Component {
  <template>
    <div class="d-form-conditional-display__condition">
      {{yield}}
      <input
        type="radio"
        name={{@id}}
        value={{@name}}
        checked={{eq @name @activeName}}
        {{on "change" (fn @setCondition @name)}}
      />
    </div>
  </template>
}
