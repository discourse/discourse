import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ReviewableHelpResources extends Component {
  @service siteSettings;

  <template>
    <div class="review-item__resources">
      <h3 class="review-item__aside-title">{{i18n "review.need_help"}}</h3>
      <ul class="review-resources__list">
        <li class="review-resources__item">
          <span class="review-resources__icon">
            {{icon "book"}}
          </span>
          <a
            href={{this.siteSettings.moderation_guide_url}}
            class="review-resources__link"
          >
            {{i18n "review.help.moderation_guide"}}
          </a>
        </li>
        <li class="review-resources__item">
          <span class="review-resources__icon">
            {{icon "book"}}
          </span>
          <a
            href={{this.siteSettings.flag_priorities_url}}
            class="review-resources__link"
          >
            {{i18n "review.help.flag_priorities"}}
          </a>
        </li>
        <li class="review-resources__item">
          <span class="review-resources__icon">
            {{icon "book"}}
          </span>
          <a
            href={{this.siteSettings.spam_detection_url}}
            class="review-resources__link"
          >
            {{i18n "review.help.spam_detection"}}
          </a>
        </li>
      </ul>
    </div>
  </template>
}
