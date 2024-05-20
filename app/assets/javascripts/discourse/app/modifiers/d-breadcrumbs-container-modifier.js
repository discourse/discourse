import { registerDestructor } from "@ember/destroyable";
import { inject as service } from "@ember/service";
import Modifier from "ember-modifier";

export default class DBreadcrumbsContainerModifier extends Modifier {
  @service breadcrumbsService;

  container = null;

  modify(element, _, { itemClass, linkClass }) {
    if (this.container) {
      return;
    }

    this.container = { element, itemClass, linkClass };

    this.breadcrumbsService.registerContainer(this.container);

    registerDestructor(this, unregisterContainer);
  }
}

function unregisterContainer(instance) {
  if (instance.container) {
    instance.breadcrumbsService.unregisterContainer(instance.container);
  }
}
