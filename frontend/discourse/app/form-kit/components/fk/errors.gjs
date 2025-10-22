import Component from "@glimmer/component";
import icon from "discourse/helpers/d-icon";

export default class FKErrors extends Component {
  concatErrors(errors) {
    return errors.join(", ");
  }

  <template>
    <p class="form-kit__errors" id={{@id}} aria-live="assertive" ...attributes>
      <span>
        {{icon "triangle-exclamation"}}
        {{this.concatErrors @error.messages}}
      </span>
    </p>
  </template>
}
