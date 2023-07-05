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
  @tracked onlySelected = false;
  @tracked onlyUnSelected = false;
  @tracked tags = [];
  @tracked tagsLoading = true;
  @tracked selectedTags = [...this.currentUser.sidebarTagNames];

  constructor() {
    super(...arguments);
    this.#loadTags();
  }

  async #loadTags() {
    this.tagsLoading = true;

    const findArgs = {};

    if (this.filter !== "") {
      findArgs.filter = this.filter;
    }

    if (this.onlySelected) {
      findArgs.only_tags = this.selectedTags.join(",");
    }

    if (this.onlyUnselected) {
      findArgs.exclude_tags = this.selectedTags.join(",");
    }

    await this.store
      .findAll("listTag", findArgs)
      .then((tags) => {
        this.tagsLoading = false;
        this.tags = tags;
      })
      .catch((error) => {
        popupAjaxError(error);
      });
  }

  @action
  didInsertTag(element) {
    const tagName = element.dataset.tagName;
    const lastTagName = this.tags.content[this.tags.content.length - 1].name;

    if (tagName === lastTagName) {
      if (this.observer) {
        this.observer.disconnect();
      } else {
        this.observer = new IntersectionObserver(
          (entries) => {
            entries.forEach((entry) => {
              if (entry.isIntersecting) {
                this.tags.loadMore();
              }
            });
          },
          {
            root: document.querySelector(".modal-body"),
            threshold: 1.0,
          }
        );
      }

      this.observer.observe(element);
    }
  }

  @action
  resetFilter() {
    this.onlySelected = false;
    this.onlyUnselected = false;
    this.#loadTags();
  }

  @action
  filterSelected() {
    this.onlySelected = true;
    this.onlyUnselected = false;
    this.#loadTags();
  }

  @action
  filterUnselected() {
    this.onlySelected = false;
    this.onlyUnselected = true;
    this.#loadTags();
  }

  @action
  onFilterInput(filter) {
    discourseDebounce(this, this.#performFiltering, filter, INPUT_DELAY);
  }

  #performFiltering(filter) {
    this.filter = filter.toLowerCase();
    this.#loadTags();
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
