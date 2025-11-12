import Component from "@glimmer/component";
import concatClass from "discourse/helpers/concat-class";
import { gt, lt } from "discourse/truth-helpers";

export default class FKCharCounter extends Component {
  get currentLength() {
    return this.args.value?.length || 0;
  }

  <template>
    <span
      class={{concatClass
        "form-kit__char-counter"
        (if (gt this.currentLength @maxLength) "--exceeded")
        (if (lt this.currentLength @minLength) "--insufficient")
      }}
      ...attributes
    >
      {{this.currentLength}}/{{@maxLength}}
    </span>
  </template>
}
