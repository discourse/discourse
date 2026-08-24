import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trackedSet } from "@ember/reactive/collections";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import { gt, has, or } from "discourse/truth-helpers";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import { i18n } from "discourse-i18n";
import EditNavigationMenuModal from "./modal";

export default class SidebarEditNavigationMenuTagsModal extends Component {
  @service currentUser;
  @service siteSettings;
  @service store;

  @tracked disableFiltering = false;
  @tracked saving = false;
  @tracked selectedTagIds = trackedSet([...this.currentUser.sidebarTagIds]);
  @tracked tags = [];
  @tracked tagsLoading = false;
  observer;
  onlySelected = false;
  onlyUnselected = false;

  constructor() {
    super(...arguments);
    this.#loadTags();
  }

  async #loadTags() {
    try {
      this.tagsLoading = true;

      const findArgs = {};

      if (this.filter) {
        findArgs.filter = this.filter;
      }

      if (this.onlySelected) {
        if (this.selectedTagIds.size === 0) {
          this.tags = [];
          return;
        }

        findArgs.only_tag_ids = [...this.selectedTagIds].join(",");
      } else if (this.onlyUnselected) {
        findArgs.exclude_tag_ids = [...this.selectedTagIds].join(",");
      }

      try {
        const tags = await this.store.findAll("listTag", findArgs);
        this.tags = tags;
      } catch (error) {
        popupAjaxError(error);
      }
    } finally {
      this.tagsLoading = false;
      this.disableFiltering = false;
    }
  }

  @action
  didInsertTag(element, [tagId]) {
    if (tagId === this.tags.content.at(-1).id) {
      if (this.observer) {
        this.observer.disconnect();
      } else {
        const root = document.querySelector(".d-modal__body");
        const style = window.getComputedStyle(root);
        const marginTop = parseFloat(style.marginTop);
        const paddingTop = parseFloat(style.paddingTop);

        this.observer = new IntersectionObserver(
          (entries) => {
            entries.forEach((entry) => {
              if (entry.isIntersecting) {
                this.tags.loadMore();
              }
            });
          },
          {
            root: document.querySelector(".d-modal__body"),
            rootMargin: `0px 0px ${marginTop + paddingTop}px 0px`,
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
    this.disableFiltering = true;
    discourseDebounce(this, this.#performFiltering, filter, INPUT_DELAY);
  }

  #performFiltering(filter) {
    this.filter = filter.toLowerCase();
    this.#loadTags();
  }

  @action
  deselectAll() {
    this.selectedTagIds.clear();
  }

  @action
  async resetToDefaults() {
    // The setting stores tag names, and the ids they resolve to are only known
    // to the server.
    try {
      const tags = await this.store.findAll("listTag", {
        only_tags: this.siteSettings.default_navigation_menu_tags.replaceAll(
          "|",
          ","
        ),
      });

      this.selectedTagIds = trackedSet(tags.content.map((tag) => tag.id));
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  toggleTag(tagId) {
    if (this.selectedTagIds.has(tagId)) {
      this.selectedTagIds.delete(tagId);
    } else {
      this.selectedTagIds.add(tagId);
    }
  }

  @action
  async save() {
    this.saving = true;
    const initialSidebarTags = this.currentUser.sidebar_tags;
    this.currentUser.set("sidebar_tag_ids", [...this.selectedTagIds]);

    try {
      const result = await this.currentUser.save(["sidebar_tag_ids"]);
      this.currentUser.set("sidebar_tags", result.user.sidebar_tags);
      this.args.closeModal();
    } catch (error) {
      this.currentUser.set("sidebar_tags", initialSidebarTags);
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <EditNavigationMenuModal
      @title="sidebar.tags_form_modal.title"
      @saving={{this.saving}}
      @save={{this.save}}
      @showResetDefaultsButton={{gt
        this.siteSettings.default_navigation_menu_tags.length
        0
      }}
      @resetToDefaults={{this.resetToDefaults}}
      @deselectAll={{this.deselectAll}}
      @deselectAllText={{i18n "sidebar.tags_form_modal.subtitle.text"}}
      @inputFilterPlaceholder={{i18n
        "sidebar.tags_form_modal.filter_placeholder"
      }}
      @onFilterInput={{this.onFilterInput}}
      @resetFilter={{this.resetFilter}}
      @filterSelected={{this.filterSelected}}
      @filterUnselected={{this.filterUnselected}}
      @closeModal={{@closeModal}}
      @loading={{or this.tagsLoading this.disableFiltering}}
      class="sidebar__edit-navigation-menu__tags-modal"
    >
      {{#if this.tagsLoading}}
        {{dLoadingSpinner size="large"}}
      {{else}}
        <form class="sidebar-tags-form">
          {{#each this.tags.content as |tag|}}
            <div
              {{didInsert this.didInsertTag tag.id}}
              data-tag-id={{tag.id}}
              class="sidebar-tags-form__tag"
            >
              <input
                {{on "click" (fn this.toggleTag tag.id)}}
                type="checkbox"
                checked={{has this.selectedTagIds tag.id}}
                id={{concat "sidebar-tags-form__input--" tag.id}}
                class="sidebar-tags-form__input"
              />

              <label
                for={{concat "sidebar-tags-form__input--" tag.id}}
                class="sidebar-tags-form__tag-label"
              >
                <p>
                  <span class="sidebar-tags-form__tag-label-name">
                    {{tag.name}}
                  </span>

                  <span class="sidebar-tags-form__tag-label-count">
                    ({{tag.topic_count}})
                  </span>
                </p>
              </label>
            </div>
          {{else}}
            <div class="sidebar-tags-form__no-tags">
              {{i18n "sidebar.tags_form_modal.no_tags"}}
            </div>
          {{/each}}
        </form>
      {{/if}}

      <DConditionalLoadingSpinner @condition={{this.tags.loadingMore}} />
    </EditNavigationMenuModal>
  </template>
}
