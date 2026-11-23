import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { trustHTML } from "@ember/template";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import { i18nForOwner } from "discourse/plugins/discourse-rewind/discourse/lib/rewind-i18n";

export default class BestPosts extends Component {
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

  rank(index) {
    return index + 1;
  }

  <template>
    <div class="rewind-report-page --best-posts">
      <h2 class="rewind-report-title">{{this.titleText}}</h2>
      <ol class="rewind-pads">
        {{#each @report.data as |post index|}}
          <li class="rewind-pads__item">
            <article class="rewind-pads__page">
              <p class="rewind-pads__rank">
                <span
                  aria-hidden="true"
                  class="rewind-medal --rank-{{this.rank index}}"
                ></span>
              </p>
              <div class="rewind-pads__excerpt">
                <p>{{trustHTML post.excerpt}}</p>
              </div>
              <p class="rewind-pads__meta">
                <span class="rewind-pads__likes">
                  {{post.like_count}}
                </span>
                <span class="rewind-pads__replies">
                  {{post.reply_count}}
                </span>
              </p>
              <a
                class="rewind-link-btn"
                href={{getURL
                  (concat "/t/" post.topic_id "/" post.post_number)
                }}
              >
                {{i18n "discourse_rewind.reports.best_posts.view_post"}}
              </a>
            </article>
          </li>
        {{/each}}
      </ol>
    </div>
  </template>
}
