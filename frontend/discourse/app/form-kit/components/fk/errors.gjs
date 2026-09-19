import Component from "@glimmer/component";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class FKErrors extends Component {
  concatErrors(errors) {
    return errors.join(", ");
  }

  <template>
    <p aria-live="assertive" class="form-kit__errors" id={{@id}} ...attributes>
      <span>
        {{dIcon "triangle-exclamation"}}
        {{this.concatErrors @error.messages}}
      </span>
    </p>
  </template>
}
