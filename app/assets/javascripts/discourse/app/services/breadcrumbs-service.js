import { tracked } from "@glimmer/tracking";
import { warn } from "@ember/debug";
import Service from "@ember/service";

export default class BreadcrumbsService extends Service {
  @tracked containers = [];
  #containers = [];

  registerContainer(container) {
    if (this.#isContainerRegistered(container)) {
      warn(
        "[BreadcrumbsService] A breadcrumb container with the same DOM element has already been registered before."
      );
    }

    this.#containers = [...this.#containers, container];

    this.containers = this.#containers;
  }

  unregisterContainer(container) {
    if (!this.#isContainerRegistered(container)) {
      warn(
        "[BreadcrumbsService] No breadcrumb container was found with this DOM element."
      );
    }

    this.#containers = this.#containers.filter((registeredContainer) => {
      return container.element !== registeredContainer.element;
    });

    this.containers = this.#containers;
  }

  #isContainerRegistered(container) {
    return this.#containers.some((registeredContainer) => {
      return container.element === registeredContainer.element;
    });
  }
}
