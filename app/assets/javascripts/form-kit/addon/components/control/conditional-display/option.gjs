import Component from "@glimmer/component";
import { next } from "@ember/runloop";

export default class FkControlConditionalDisplayOption extends Component {
  constructor() {
    super(...arguments);

    next(() => {
      this.args.registerOption(this.args.id, this.args.label);
    });
  }

  <template>
    <div class="d-form-conditional-display__option">
      {{@id}}
      {{yield}}
    </div>
  </template>
}
