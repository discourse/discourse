import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import { i18nForOwner } from "discourse/plugins/discourse-rewind/discourse/lib/rewind-i18n";

export default class BestPosts extends Component {
  rankClass(idx) {
    return `rank-${idx + 1}`;
  }

  get titleText() {
    return i18nForOwner(
      "discourse_rewind.reports.best_posts.title",
      this.args.isOwnRewind,
      {
        count: this.args.report.data.length,
        username: this.args.user?.username,
      }
    );
  }

  <template>
    {{#if @report.data.length}}
      <div class="rewind-report-page --best-posts">
        <h2 class="rewind-report-title">
          {{this.titleText}}
        </h2>
        <div class="rewind-report-container">
          {{#each @report.data as |post idx|}}
            <div class={{concatClass "rewind-card" (this.rankClass idx)}}>
              <span class="best-posts --rank"></span>
              <span class="best-posts --rank"></span>
              <div class="best-posts__post">
                <p>{{htmlSafe post.excerpt}}</p>
              </div>
              <div class="best-posts__metadata">
                <span class="best-posts__likes">
                  {{icon "heart"}}{{post.like_count}}
                </span>
                <span class="best-posts__replies">
                  {{icon "comment"}}{{post.reply_count}}
                </span>
                <a
                  href={{getURL
                    (concat "/t/" post.topic_id "/" post.post_number)
                  }}
                >
                  {{i18n "discourse_rewind.reports.best_posts.view_post"}}
                </a>
              </div>
            </div>
          {{/each}}
        </div>
      </div>
    {{/if}}
  </template>
}
