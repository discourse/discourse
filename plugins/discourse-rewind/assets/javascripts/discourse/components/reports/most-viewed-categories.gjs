import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import getURL from "discourse/lib/get-url";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import RewindWindow from "discourse/plugins/discourse-rewind/discourse/components/rewind-window";
import { i18nForOwner } from "discourse/plugins/discourse-rewind/discourse/lib/rewind-i18n";

export default class MostViewedCategories extends Component {
  @tracked openedCategoryId = null;

  get titleText() {
    return i18nForOwner(
      "discourse_rewind.reports.most_viewed_categories.title",
      this.args.isOwnRewind,
      {
        count: this.args.report.data.length,
        username: this.args.user?.username,
      }
    );
  }

  /**
   * Handles click on folder-wrapper, we want to open
   * the folder on click then navigate to it on second click.
   * @action
   */
  @action
  handleFolderClick(categoryId, event) {
    if (this.openedCategoryId === categoryId) {
      return;
    }

    event.preventDefault();
    this.openedCategoryId = categoryId;
  }

  <template>
    <div class="rewind-report-page --most-viewed-categories">
      <h2 class="rewind-report-title">{{this.titleText}}</h2>
      <RewindWindow>
        <ol class="rewind-categories">
          {{#each @report.data as |data index|}}
            <li>
              <a
                class={{dConcatClass
                  "rewind-categories__category"
                  (if (eq this.openedCategoryId data.category_id) "--opened")
                }}
                data-pattern={{index}}
                href={{getURL (concat "/c/-/" data.category_id)}}
                {{on "click" (fn this.handleFolderClick data.category_id)}}
              >
                <span class="rewind-categories__thumb">
                  <span class="rewind-categories__name">#{{data.name}}</span>
                </span>
              </a>
            </li>
          {{/each}}
        </ol>
      </RewindWindow>
    </div>
  </template>
}
