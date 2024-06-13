import Component from "@glimmer/component";
import { gt } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";

export default class CharCounter extends Component {
  get currentLength() {
    return this.args.value?.length || 0;
  }

  <template>
    <span
      class={{concatClass
        "d-form__char-counter"
        (if (gt this.currentLength @maxLength) "--exceeded")
      }}
      ...attributes
    >
      {{this.currentLength}}/{{@maxLength}}
    </span>
  </template>
}
