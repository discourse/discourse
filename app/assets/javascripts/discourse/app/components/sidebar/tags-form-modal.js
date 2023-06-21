import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

import { popupAjaxError } from "discourse/lib/ajax-error";
import { INPUT_DELAY } from "discourse-common/config/environment";
import discourseDebounce from "discourse-common/lib/debounce";

export default class extends Component {
  @service currentUser;
  @service siteSettings;
  @service store;

  @tracked filter = "";
  @tracked tags = [];
  @tracked tagsLoading = true;
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

        this.tagsLoading = false;
      })
      .catch((error) => {
        popupAjaxError(error);
      });
  }

  get filteredTags() {
    if (this.filter.length === 0) {
      return this.tags;
    } else {
      return this.tags.reduce((acc, tag) => {
        if (tag.name.toLowerCase().includes(this.filter)) {
          acc.push(tag);
        }

        return acc;
      }, []);
    }
  }

  get modalHeaderAfterTitleElement() {
    return document.getElementById("modal-header-after-title");
  }

  @action
  onFilterInput(filter) {
    discourseDebounce(this, this.#performFiltering, filter, INPUT_DELAY);
  }

  #performFiltering(filter) {
    this.filter = filter.toLowerCase();
  }

  @action
  deselectAll() {
    this.selectedTags.clear();
  }

  @action
  resetToDefaults() {
    this.selectedTags =
      this.siteSettings.default_navigation_menu_tags.split("|");
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
