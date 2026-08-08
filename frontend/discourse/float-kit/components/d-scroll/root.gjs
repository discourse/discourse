import Component from "@glimmer/component";
import { registerDestructor } from "@ember/destroyable";
import mergeScrollAttributes from "../../modifiers/merge-scroll-attributes";
import ScrollController from "./controller";

export default class DScrollRoot extends Component {
  controller = new ScrollController();

  constructor() {
    super(...arguments);

    registerDestructor(this, () => {
      this.controller.cleanup();
    });
  }

  <template>
    <div ...attributes {{mergeScrollAttributes "root"}}>
      {{yield this.controller}}
    </div>
  </template>
}
