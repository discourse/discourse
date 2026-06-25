import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { isHttpUrl } from "discourse/lib/url";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { i18n } from "discourse-i18n";
import {
  itemNote,
  STATUS_MODIFIERS,
} from "discourse/plugins/discourse-rss-polling/discourse/lib/rss-polling-item";

export default class RssPollingFeedItemList extends Component {
  @cached
  get items() {
    return (this.args.items ?? []).map((item) => ({
      modifier: STATUS_MODIFIERS[item.status] ?? "--skip",
      label: item.title || item.url,
      url: isHttpUrl(item.url) ? item.url : null,
      publishedAt: item.published_at,
      note: itemNote(item),
    }));
  }

  get truncated() {
    return this.args.total != null && this.args.total > this.items.length;
  }

  <template>
    <ul class="rss-polling-feed-test__list">
      {{#each this.items as |item|}}
        <li class="rss-polling-feed-test__item {{item.modifier}}">
          <div class="rss-polling-feed-test__body">
            {{#if item.url}}
              <a
                class="rss-polling-feed-test__item-title"
                href={{item.url}}
                target="_blank"
                rel="noopener noreferrer"
              >
                {{item.label}}
              </a>
            {{else}}
              <span class="rss-polling-feed-test__item-title">
                {{item.label}}
              </span>
            {{/if}}
            {{#if item.publishedAt}}
              <span class="rss-polling-feed-test__item-date">
                {{dFormatDate item.publishedAt}}
              </span>
            {{/if}}
            {{#if item.note}}
              <span class="rss-polling-feed-test__item-reason">
                {{item.note}}
              </span>
            {{/if}}
          </div>
        </li>
      {{/each}}
    </ul>
    {{#if this.truncated}}
      <p class="rss-polling-feed-test__more">
        {{i18n
          "admin.rss_polling.showing"
          count=this.items.length
          total=@total
        }}
      </p>
    {{/if}}
  </template>
}
