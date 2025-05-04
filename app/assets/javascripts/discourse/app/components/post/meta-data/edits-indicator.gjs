import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { longDate } from "discourse/lib/formatter";
import { i18n } from "discourse-i18n";

export default class PostMetaDataEditsIndicator extends Component {
  @service siteSettings;

  get icon() {
    return this.args.post.wiki ? "far-pen-to-square" : "pencil";
  }

  get label() {
    if (this.args.post.version > 1) {
      return this.args.post.version - 1;
    }
  }

  get title() {
    const date = longDate(this.updatedAt);

    if (this.args.post.wiki) {
      if (this.args.post.version > 1) {
        return i18n("post.wiki_last_edited_on", { dateTime: date });
      } else {
        return i18n("post.wiki.about");
      }
    } else {
      return i18n("post.last_edited_on", { dateTime: date });
    }
  }

  get updatedAt() {
    return new Date(this.args.post.updated_at);
  }

  @action
  onPostEditsIndicatorClick() {
    if (this.args.post.wiki && this.args.post.version === 1) {
      this.args.editPost();
    } else if (this.args.post.can_view_edit_history) {
      this.args.showHistory();
    }
  }

  <template>
    <div class="post-info edits">
      <DButton
        class={{concatClass
          "btn-flat"
          (historyHeat this.siteSettings this.updatedAt)
          (if @post.wiki "wiki")
        }}
        @icon={{this.icon}}
        @translatedLabel={{this.label}}
        @translatedTitle={{this.title}}
        @translatedAriaLabel={{i18n "post.edit_history"}}
        @action={{this.onPostEditsIndicatorClick}}
      />
    </div>
  </template>
}

function mult(val) {
  return 60 * 50 * 1000 * val;
}

export function historyHeat(siteSettings, updatedAt) {
  if (!updatedAt) {
    return;
  }

  // Show heat on age
  const rightNow = Date.now();
  const updatedAtTime = updatedAt.getTime();

  if (updatedAtTime > rightNow - mult(siteSettings.history_hours_low)) {
    return "heatmap-high";
  }

  if (updatedAtTime > rightNow - mult(siteSettings.history_hours_medium)) {
    return "heatmap-med";
  }

  if (updatedAtTime > rightNow - mult(siteSettings.history_hours_high)) {
    return "heatmap-low";
  }
}
