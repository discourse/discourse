import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { inject as service } from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

@disableImplicitInjections
export default class Card extends Service {
  @service menu;

  @tracked activeCard;
  @tracked opts = {};
  @tracked containerElement;

  @action
  setContainerElement(element) {
    this.containerElement = element;
  }

  show(component, target, opts = {}) {
    this.close();

    const instance = this.menu.show(target, {
      identifier: "d-card",
      component,
      data: {
        user: opts.model.user,
      },
    });

    let resolveShowPromise;
    const promise = new Promise((resolve) => {
      resolveShowPromise = resolve;
    });

    this.activeCard = { instance, resolveShowPromise };

    return promise;
  }

  close(data) {
    this.activeCard?.resolveShowPromise?.(data);
    this.activeCard = null;
    this.opts = {};
  }
}
