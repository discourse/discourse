import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

import { popupAjaxError } from "discourse/lib/ajax-error";

export default class extends Component {
  @service currentUser;
  @service store;
  @tracked tags = [];
  @tracked selectedTags = [...this.currentUser.sidebarTagNames];

  constructor() {
    super(...arguments);
    this.#loadTags();
  }

  async #loadTags() {
    // This is loading all tags upfront and there is no pagination for it. However, this is what we are doing for the
    // `/tags` route as well so we have decided to kick this can of worms down the road for now.
    await this.store
      .findAll("tag")
      .then((tags) => {
        this.tags = tags.content.sort((a, b) => {
          return a.name.localeCompare(b.name);
        });
      })
      .catch((error) => {
        popupAjaxError(error);
      });
  }

  @action
  toggleTag(tag) {
    if (this.selectedTags.includes(tag)) {
      this.selectedTags.removeObject(tag);
    } else {
      this.selectedTags.addObject(tag);
    }
  }

  @action
  save() {
    this.saving = true;
    const initialSidebarTags = this.currentUser.sidebar_tags;
    this.currentUser.set("sidebar_tag_names", this.selectedTags);

    this.currentUser
      .save(["sidebar_tag_names"])
      .then((result) => {
        this.currentUser.set("sidebar_tags", result.user.sidebar_tags);
        this.args.closeModal();
      })
      .catch((error) => {
        this.currentUser.set("sidebar_tags", initialSidebarTags);
        popupAjaxError(error);
      })
      .finally(() => {
        this.saving = false;
      });
  }
}
