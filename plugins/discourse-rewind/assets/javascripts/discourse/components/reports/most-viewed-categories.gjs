import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import getURL from "discourse/lib/get-url";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

/**
 * Component displaying most viewed categories in rewind report
 * @component
 * @param {Object} report - Report data containing category view counts
 */
export default class MostViewedCategories extends Component {
  @tracked openedCategoryId = null;

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
    {{#if @report.data.length}}
      <div class="rewind-report-page --most-viewed-categories">
        <h2 class="rewind-report-title">
          {{i18n
            "discourse_rewind.reports.most_viewed_categories.title"
            count=@report.data.length
          }}
        </h2>
        <div class="rewind-report-container">
          {{#each @report.data as |data|}}
            <a
              class={{concatClass
                "folder-wrapper"
                (if (eq this.openedCategoryId data.category_id) "--opened" "")
              }}
              href={{getURL (concat "/c/-/" data.category_id)}}
              {{on "click" (fn this.handleFolderClick data.category_id)}}
            >
              <span class="folder-tab"></span>
              <div class="rewind-card">
                <p class="most-viewed-categories__category">#{{data.name}}</p>
              </div>
              <span class="folder-bg"></span>
            </a>
          {{/each}}
        </div>
      </div>
    {{/if}}
  </template>
}
