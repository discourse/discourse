import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { emojiUnescape, sanitize } from "discourse/lib/text";
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

  get grantedLabel() {
    const { badge, count } = this.args;

    if (count == null) {
      const total = badge.grant_count;
      if (total) {
        return i18n("badges.awarded", { count: total, number: dNumber(total) });
      }
    } else if (count > 1) {
      return i18n("badges.granted_times", { count, number: dNumber(count) });
    }
  }

  get summary() {
    const { badge } = this.args;

    if (this.size === "large" && !isEmpty(badge.long_description)) {
      return emojiUnescape(sanitize(badge.long_description));
    }
    return sanitize(badge.description);
  }

  get ariaDescribedBy() {
    const { badge } = this.args;
    const ids = [`badge-summary-${badge.slug}`];

    if (this.grantedLabel) {
      ids.push(`badge-granted-${badge.slug}`);
    }

    if (this.args.granted) {
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
            {{#if this.grantedLabel}}
              <div class="badge-granted" id="badge-granted-{{@badge.slug}}">
                {{trustHTML this.grantedLabel}}
              </div>
            {{/if}}
          </div>
        </div>
      </div>

      {{#if @granted}}
        <div
          aria-label={{i18n "notifications.titles.granted_badge"}}
          class="check-display status-checked"
          id="badge-awarded-{{@badge.slug}}"
        >
          {{dIcon "check"}}
        </div>
      {{/if}}

      {{#if @canFavorite}}
        <DButton
          class="btn-default favorite-btn btn-small"
          @action={{@onFavoriteClick}}
          @disabled={{and (not @isFavorite) (not @canFavoriteMoreBadges)}}
          @icon={{if @isFavorite "star" "far-star"}}
          @title={{unless
            @isFavorite
            (if
              @canFavoriteMoreBadges
              "badges.favorite_max_not_reached"
              "badges.favorite_max_reached"
            )
          }}
        />
      {{/if}}
    </div>
  </template>
}
