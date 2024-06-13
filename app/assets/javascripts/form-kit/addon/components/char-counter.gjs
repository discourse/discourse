import Component from "@glimmer/component";
import concatClass from "discourse/helpers/concat-class";

export default class CharCounter extends Component {
  get currentLength() {
    return this.args.value?.length || 0;
  }

  get exceeded() {
    return this.currentLength > this.args.maxLength;
  }

  <template>
    <span
      class={{concatClass
        "d-form__char-counter"
        (if this.exceeded "--exceeded")
      }}
      ...attributes
    >
      {{this.currentLength}}/{{@maxLength}}
    </span>
  </template>
}
