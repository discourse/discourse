import Component from "@glimmer/component";
import { registerDestructor } from "@ember/destroyable";
import ScrollController from "./controller";

export default class DScrollRoot extends Component {
  controller = new ScrollController();

  constructor() {
    super(...arguments);

    registerDestructor(this, () => {
      this.controller.cleanup();
    });
  }

  <template>{{yield this.controller}}</template>
}
