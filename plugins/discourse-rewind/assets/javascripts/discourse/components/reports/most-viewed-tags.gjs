import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import getURL from "discourse/lib/get-url";
import { eq } from "discourse/truth-helpers";
import { i18nForOwner } from "discourse/plugins/discourse-rewind/discourse/lib/rewind-i18n";

export default class MostViewedTags extends Component {
  @tracked openedTag = null;

  get titleText() {
    return i18nForOwner(
      "discourse_rewind.reports.most_viewed_tags.title",
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
  handleFolderClick(tag, event) {
    if (this.openedTag === tag) {
      return;
    }

    event.preventDefault();
    this.openedTag = tag;
  }

  <template>
    {{#if @report.data.length}}
      <div class="rewind-report-page --most-viewed-tags">
        <h2 class="rewind-report-title">{{this.titleText}}</h2>
        <div class="rewind-report-container">
          {{#each @report.data as |data|}}
            <a
              class={{concatClass
                "folder-wrapper"
                (if (eq this.openedTag data.name) "--opened" "")
              }}
              href={{getURL (concat "/tag/" data.name)}}
              {{on "click" (fn this.handleFolderClick data.name)}}
            >
              <span class="folder-tab"></span>
              <div class="rewind-card">
                <p class="most-viewed-tags__tag">
                  #{{data.name}}
                </p>
              </div>
              <span class="folder-bg"></span>
            </a>
          {{/each}}
        </div>
      </div>
    {{/if}}
  </template>
}
