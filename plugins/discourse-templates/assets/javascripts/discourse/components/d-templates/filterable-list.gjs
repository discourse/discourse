import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action, computed } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import TextField from "discourse/components/text-field";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import {
  ALL_TAGS_ID,
  NO_TAG_ID,
} from "discourse/select-kit/components/tag-drop";
import { i18n } from "discourse-i18n";
import Item from "./item";
import TagDrop from "./tag-drop";

const PREV_TEMPLATE_TAG_ID = "template-selected-tag";

export default class DTemplatesFilterableList extends Component {
  @service siteSettings;
  @service keyValueStore;

  @tracked loading = true;
  @tracked listFilter = "";
  @tracked replies = [];
  @tracked selectedTag = ALL_TAGS_ID;
  @tracked availableTags = [];

  @computed("replies", "selectedTag", "listFilter")
  get filteredReplies() {
    const filterTitle = this.listFilter.toLowerCase();
    return (
      this.replies
        .map((template) => {
          /* Give a relevant score to each template. */
          template.score = 0;
          if (template.title.toLowerCase().includes(filterTitle)) {
            template.score += 2;
          } else if (template.content.toLowerCase().includes(filterTitle)) {
            template.score += 1;
          }
          return template;
        })
        // Filter irrelevant replies.
        .filter((template) => template.score !== 0)
        // Filter only replies tagged with the selected tag.
        .filter((template) => {
          if (this.selectedTag === ALL_TAGS_ID) {
            return true;
          }
          if (this.selectedTag === NO_TAG_ID && template.tags.length === 0) {
            return true;
          }

          return template.tags.includes(this.selectedTag);
        })
        .sort((a, b) => {
          /* Sort replies by relevance, usage, and title. */
          if (a.score !== b.score) {
            return a.score > b.score ? -1 : 1; /* descending */
          } else if (a.usages !== b.usages) {
            return a.usages > b.usages ? -1 : 1; /* descending */
          } else if (a.title !== b.title) {
            return a.title < b.title ? -1 : 1; /* ascending */
          }
          return 0;
        })
    );
  }

  @bind
  async load() {
    try {
      this.loading = true;

      const results = await ajax("/discourse_templates");
      this.replies = results.templates;

      if (this.siteSettings.tagging_enabled) {
        this.availableTags = Object.values(
          this.replies.reduce((availableTags, template) => {
            template.tags.forEach((tag) => {
              if (availableTags[tag]) {
                availableTags[tag].count += 1;
              } else {
                availableTags[tag] = { id: tag, name: tag, count: 1 };
              }
            });

            return availableTags;
          }, {})
        );

        const prevSelectedTag = this.keyValueStore.get(PREV_TEMPLATE_TAG_ID);
        if (
          prevSelectedTag &&
          (prevSelectedTag === NO_TAG_ID ||
            this.availableTags.find((t) => t.id === prevSelectedTag))
        ) {
          this.selectedTag = prevSelectedTag;
        } else {
          this.keyValueStore.remove(PREV_TEMPLATE_TAG_ID);
        }
      }
    } catch (e) {
      this.loading = false;
      popupAjaxError(e);
    } finally {
      this.loading = false;

      schedule("afterRender", () =>
        document.querySelector(".templates-filter")?.focus()
      );
    }
  }

  @action
  changeSelectedTag(tagId) {
    this.selectedTag = tagId;
    if (tagId === ALL_TAGS_ID) {
      this.keyValueStore.remove(PREV_TEMPLATE_TAG_ID);
      return;
    }
    this.keyValueStore.set({ key: PREV_TEMPLATE_TAG_ID, value: tagId });
  }

  @action
  insertTemplate(template) {
    this.args.onBeforeInsertTemplate?.();
    this.args.onInsertTemplate?.(template);
    this.args.onAfterInsertTemplate?.();
  }

  <template>
    <div class="templates-filterable-list" {{didInsert this.load}}>

      <ConditionalLoadingSpinner @condition={{this.loading}}>
        <div class="templates-filter-bar">
          {{#if this.siteSettings.tagging_enabled}}
            <TagDrop
              @availableTags={{this.availableTags}}
              @tagId={{this.selectedTag}}
              @onChangeSelectedTag={{this.changeSelectedTag}}
            />
          {{/if}}
          <TextField
            class="templates-filter"
            @value={{this.listFilter}}
            placeholder={{i18n "templates.filter_hint"}}
          />
        </div>
        <div class="templates-list">
          {{#each this.filteredReplies as |r|}}
            <Item
              @template={{r}}
              @model={{@model}}
              @onInsertTemplate={{this.insertTemplate}}
            />
          {{/each}}
        </div>
      </ConditionalLoadingSpinner>
    </div>
  </template>
}
