import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

export default class extends Component {
  @service store;
  @tracked tags = [];

  constructor() {
    super(...arguments);
    this.#loadTags();
  }

  async #loadTags() {
    await this.store.findAll("tag").then((tags) => {
      this.tags = tags.content;
    });
  }
}
