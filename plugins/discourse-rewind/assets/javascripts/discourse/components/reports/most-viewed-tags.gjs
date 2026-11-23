import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import getURL from "discourse/lib/get-url";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
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
    <div class="rewind-report-page --most-viewed-tags">
      <h2 class="rewind-report-title">{{this.titleText}}</h2>
      <ol class="rewind-tags">
        {{#each @report.data as |data index|}}
          <li>
            <a
              class={{dConcatClass
                "rewind-tags__tag"
                (if (eq this.openedTag data.name) "--opened")
              }}
              data-pile={{index}}
              href={{getURL (concat "/tag/" data.slug "/" data.tag_id)}}
              {{on "click" (fn this.handleFolderClick data.name)}}
            >
              <span class="rewind-tags__name">#{{data.name}}</span>
            </a>
          </li>
        {{/each}}
      </ol>
    </div>
  </template>
}
