import Component from "@glimmer/component";
import { service } from "@ember/service";
import { isPresent } from "@ember/utils";
import getURL from "discourse/lib/get-url";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class HelpResources extends Component {
  @service siteSettings;

  get moderatorGuideUrl() {
    if (isPresent(this.siteSettings.moderator_guide_topic)) {
      return getURL("/t/") + this.siteSettings.moderator_guide_topic;
    }
  }

  <template>
    <div class="review-item__resources">
      <h3 class="review-item__aside-title">{{i18n "review.need_help"}}</h3>
      <ul class="review-resources__list">
        {{#if this.moderatorGuideUrl}}
          <li class="review-resources__item">
            <span class="review-resources__icon">
              {{dIcon "book"}}
            </span>
            <a class="review-resources__link" href={{this.moderatorGuideUrl}}>
              {{i18n "review.help.community_moderation_guide"}}
            </a>
          </li>
        {{/if}}
        <li class="review-resources__item">
          <span class="review-resources__icon">
            {{dIcon "book"}}
          </span>
          <a
            class="review-resources__link"
            href="https://meta.discourse.org/t/-/63116"
          >
            {{i18n "review.help.moderation_guide"}}
          </a>
        </li>
        <li class="review-resources__item">
          <span class="review-resources__icon">
            {{dIcon "book"}}
          </span>
          <a
            class="review-resources__link"
            href="https://meta.discourse.org/t/-/123464"
          >
            {{i18n "review.help.flag_priorities"}}
          </a>
        </li>
        <li class="review-resources__item">
          <span class="review-resources__icon">
            {{dIcon "book"}}
          </span>
          <a
            class="review-resources__link"
            href="https://meta.discourse.org/t/-/343541"
          >
            {{i18n "review.help.spam_detection"}}
          </a>
        </li>
      </ul>
    </div>
  </template>
}
