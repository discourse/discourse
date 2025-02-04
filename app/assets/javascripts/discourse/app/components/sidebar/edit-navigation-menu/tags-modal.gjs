import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { TrackedSet } from "@ember-compat/tracked-built-ins";
import { gt, has, or } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import loadingSpinner from "discourse/helpers/loading-spinner";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import { i18n } from "discourse-i18n";
import EditNavigationMenuModal from "./modal";

export default class SidebarEditNavigationMenuTagsModal extends Component {
  @service currentUser;
  @service siteSettings;
  @service store;

  @tracked disableFiltering = false;
  @tracked saving = false;
  @tracked selectedTags = new TrackedSet([...this.currentUser.sidebarTagNames]);
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
    this.tagsLoading = true;

    const findArgs = {};

    if (this.filter) {
      findArgs.filter = this.filter;
    }

    if (this.onlySelected) {
      findArgs.only_tags = [...this.selectedTags].join(",");
    } else if (this.onlyUnselected) {
      findArgs.exclude_tags = [...this.selectedTags].join(",");
    }

    try {
      const tags = await this.store.findAll("listTag", findArgs);
      this.tags = tags;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.tagsLoading = false;
      this.disableFiltering = false;
    }
  }

  @action
  didInsertTag(element) {
    const tagName = element.dataset.tagName;
    const lastTagName = this.tags.content[this.tags.content.length - 1].name;

    if (tagName === lastTagName) {
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
    this.selectedTags.clear();
  }

  @action
  resetToDefaults() {
    this.selectedTags = new TrackedSet(
      this.siteSettings.default_navigation_menu_tags.split("|")
    );
  }

  @action
  toggleTag(tag) {
    if (this.selectedTags.has(tag)) {
      this.selectedTags.delete(tag);
    } else {
      this.selectedTags.add(tag);
    }
  }

  @action
  async save() {
    this.saving = true;
    const initialSidebarTags = this.currentUser.sidebar_tags;
    this.currentUser.set("sidebar_tag_names", [...this.selectedTags]);

    try {
      const result = await this.currentUser.save(["sidebar_tag_names"]);
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
        {{loadingSpinner size="large"}}
      {{else}}
        <form class="sidebar-tags-form">
          {{#each this.tags as |tag|}}
            <div
              {{didInsert this.didInsertTag}}
              data-tag-name={{tag.name}}
              class="sidebar-tags-form__tag"
            >
              <input
                {{on "click" (fn this.toggleTag tag.name)}}
                type="checkbox"
                checked={{has this.selectedTags tag.name}}
                id={{concat "sidebar-tags-form__input--" tag.name}}
                class="sidebar-tags-form__input"
              />

              <label
                for={{concat "sidebar-tags-form__input--" tag.name}}
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

      <ConditionalLoadingSpinner @condition={{this.tags.loadingMore}} />
    </EditNavigationMenuModal>
  </template>
}
