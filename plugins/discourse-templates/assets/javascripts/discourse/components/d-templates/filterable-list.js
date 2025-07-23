import { action, computed } from "@ember/object";
import { inject as service } from "@ember/service";
import { schedule } from "@ember/runloop";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { bind } from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ALL_TAGS_ID, NO_TAG_ID } from "select-kit/components/tag-drop";

export default class DTemplatesFilterableList extends Component {
  @service siteSettings;

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
          /* Sort replies by relevance and title. */
          if (a.score !== b.score) {
            return a.score > b.score ? -1 : 1; /* descending */
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
  }

  @action
  insertTemplate(template) {
    this.args.onBeforeInsertTemplate?.();
    this.args.onInsertTemplate?.(template);
    this.args.onAfterInsertTemplate?.();
  }
}
