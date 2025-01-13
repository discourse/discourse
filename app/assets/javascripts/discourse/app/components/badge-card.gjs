import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { eq, not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import dIcon from "discourse/helpers/d-icon";
import iconOrImage from "discourse/helpers/icon-or-image";
import number from "discourse/helpers/number";
import { emojiUnescape, sanitize } from "discourse/lib/text";
import { i18n } from "discourse-i18n";
import PluginOutlet from "./plugin-outlet";

export default class BadgeCard extends Component {
  @tracked size = this.args.size || "medium";

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
    const { size, badge } = this.args;

    if (size === "large" && !isEmpty(badge.long_description)) {
      return emojiUnescape(sanitize(badge.long_description));
    }
    return sanitize(badge.description);
  }

  get showFavorite() {
    const { badge } = this.args;
    return ![1, 2, 3, 4].includes(badge.id);
  }

  <template>
    <div
      class="badge-card --badge-{{this.size}}"
      data-badge-slug={{@badge.slug}}
    >
      <div class="badge-contents">
        <PluginOutlet
          @name="badge-contents-top"
          @outletArgs={{hash badge=@badge url=this.url}}
        />
        <span
          class="badge-icon {{@badge.badgeTypeClassName}}"
          aria-hidden="true"
        >
          {{iconOrImage @badge}}
        </span>
        <div class="badge-info">
          <div class="badge-info-item">
            <h3>
              {{#if (eq this.size "large")}}
                {{@badge.name}}
              {{else}}
                <a
                  href={{this.url}}
                  class="badge-link"
                  aria-describedby="badge-summary-{{@badge.slug}} badge-granted-{{@badge.slug}} badge-awarded-{{@badge.slug}}"
                >
                  {{@badge.name}}
                </a>
              {{/if}}
            </h3>
            <div id="badge-summary-{{@badge.slug}}" class="badge-summary">
              {{htmlSafe this.summary}}
            </div>
            {{#if this.displayCount}}
              <div id="badge-granted-{{@badge.slug}}" class="badge-granted">
                {{htmlSafe
                  (i18n
                    "badges.awarded"
                    count=this.displayCount
                    number=(number this.displayCount)
                  )
                }}
              </div>
            {{/if}}
          </div>
        </div>
      </div>

      {{#if @badge.has_badge}}
        <div
          id="badge-awarded-{{@badge.slug}}"
          class="check-display status-checked"
          aria-label={{i18n "notifications.titles.granted_badge"}}
        >
          {{dIcon "check"}}
        </div>
      {{/if}}

      {{#if @canFavorite}}
        {{#if @isFavorite}}
          <DButton
            @icon="star"
            @action={{@onFavoriteClick}}
            class="favorite-btn"
          />
        {{else}}
          <DButton
            @icon="far-star"
            @action={{@onFavoriteClick}}
            @title={{if
              @canFavoriteMoreBadges
              "badges.favorite_max_not_reached"
              "badges.favorite_max_reached"
            }}
            @disabled={{not @canFavoriteMoreBadges}}
            class="favorite-btn"
          />
        {{/if}}
      {{/if}}
    </div>
  </template>
}
