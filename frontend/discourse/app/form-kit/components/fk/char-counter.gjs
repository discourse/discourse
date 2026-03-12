import Component from "@glimmer/component";
import { gt, lt } from "discourse/truth-helpers";
import concatClass from "discourse/ui-kit/helpers/d-concat-class";

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
