import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { emojiUnescape, sanitize } from "discourse/lib/text";
import { eq, not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dIconOrImage from "discourse/ui-kit/helpers/d-icon-or-image";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";

export default class DBadgeCard extends Component {
  get size() {
    return this.args.size || "medium";
  }

  get url() {
    const { badge, filterUser, username } = this.args;
    return filterUser ? `${badge.url}?username=${username}` : badge.url;
  }

  get displayCount() {
    const { count, badge } = this.args;
    if (count == null) {
      return badge.grant_count;
    }
    if (count > 1) {
      return count;
    }
  }

  get summary() {
    const { badge } = this.args;

    if (this.size === "large" && !isEmpty(badge.long_description)) {
      return emojiUnescape(sanitize(badge.long_description));
    }
    return sanitize(badge.description);
  }

  get showFavorite() {
    const { badge } = this.args;
    return ![1, 2, 3, 4].includes(badge.id);
  }

  get ariaDescribedBy() {
    const { badge } = this.args;
    const ids = [`badge-summary-${badge.slug}`];

    if (this.displayCount) {
      ids.push(`badge-granted-${badge.slug}`);
    }

    if (badge.has_badge) {
      ids.push(`badge-awarded-${badge.slug}`);
    }

    return ids.join(" ");
  }

  <template>
    <div
      class="badge-card --badge-{{this.size}}{{if
          @canFavorite
          ' --can-favorite'
        }}"
      data-badge-slug={{@badge.slug}}
    >
      <div class="badge-contents">
        <PluginOutlet
          @name="badge-contents-top"
          @outletArgs={{lazyHash badge=@badge url=this.url}}
        />
        <span
          aria-hidden="true"
          class="badge-icon {{@badge.badgeTypeClassName}}"
        >
          {{dIconOrImage @badge}}
        </span>
        <div class="badge-info">
          <div class="badge-info-item">
            <h3>
              {{#if (eq this.size "large")}}
                {{@badge.name}}
              {{else}}
                <a
                  aria-describedby={{this.ariaDescribedBy}}
                  class="badge-link"
                  href={{this.url}}
                >
                  {{@badge.name}}
                </a>
              {{/if}}
            </h3>
            <div class="badge-summary" id="badge-summary-{{@badge.slug}}">
              {{trustHTML this.summary}}
            </div>
            {{#if this.displayCount}}
              <div class="badge-granted" id="badge-granted-{{@badge.slug}}">
                {{trustHTML
                  (i18n
                    "badges.awarded"
                    count=this.displayCount
                    number=(dNumber this.displayCount)
                  )
                }}
              </div>
            {{/if}}
          </div>
        </div>
      </div>

      {{#if @badge.has_badge}}
        <div
          aria-label={{i18n "notifications.titles.granted_badge"}}
          class="check-display status-checked"
          id="badge-awarded-{{@badge.slug}}"
        >
          {{dIcon "check"}}
        </div>
      {{/if}}

      {{#if @canFavorite}}
        {{#if @isFavorite}}
          <DButton
            class="btn-default favorite-btn btn-small"
            @action={{@onFavoriteClick}}
            @icon="star"
          />
        {{else}}
          <DButton
            class="btn-default favorite-btn btn-small"
            @action={{@onFavoriteClick}}
            @disabled={{not @canFavoriteMoreBadges}}
            @icon="far-star"
            @title={{if
              @canFavoriteMoreBadges
              "badges.favorite_max_not_reached"
              "badges.favorite_max_reached"
            }}
          />
        {{/if}}
      {{/if}}
    </div>
  </template>
}
