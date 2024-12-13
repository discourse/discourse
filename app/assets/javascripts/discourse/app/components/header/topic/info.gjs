import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { and, gt, not, or } from "truth-helpers";
import categoryLink from "discourse/helpers/category-link";
import concatClass from "discourse/helpers/concat-class";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import renderTags from "discourse/lib/render-tags";
import DiscourseURL from "discourse/lib/url";
import icon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";
import PluginOutlet from "../../plugin-outlet";
import FeaturedLink from "./featured-link";
import Participant from "./participant";
import Status from "./status";

export default class Info extends Component {
  @service currentUser;
  @service site;
  @service siteSettings;

  get showPM() {
    return (
      !this.args.topicInfo.is_warning && this.args.topicInfo.isPrivateMessage
    );
  }

  get totalParticipants() {
    return (
      (this.args.topicInfo.details.allowed_users?.length || 0) +
      (this.args.topicInfo.allowed_groups?.length || 0)
    );
  }

  get maxExtraItems() {
    return this.args.topicInfo.tags?.length > 0 ? 5 : 10;
  }

  get twoRows() {
    return (
      this.tags?.length ||
      this.showPM ||
      this.siteSettings.topic_featured_link_enabled
    );
  }

  get tags() {
    if (this.args.topicInfo.get("tags")) {
      return renderTags(this.args.topicInfo);
    }
  }

  get remainingParticipantCount() {
    return this.totalParticipants - this.maxExtraItems;
  }

  get participants() {
    const participants = [
      ...this.args.topicInfo.details.allowed_users,
      ...this.args.topicInfo.details.allowed_groups,
    ];
    return participants.slice(0, this.maxExtraItems);
  }

  get pmHref() {
    return this.currentUser.pmPath(this.args.topicInfo);
  }

  @action
  jumpToTopPost(e) {
    if (wantsNewWindow(e)) {
      return;
    }

    e.preventDefault();
    if (this.args.topicInfo) {
      DiscourseURL.routeTo(this.args.topicInfo.firstPostUrl, {
        keepFilter: true,
      });
    }
  }

  <template>
    <div
      class={{concatClass (if this.twoRows "two-rows") "extra-info-wrapper"}}
    >
      <PluginOutlet
        @name="header-topic-info__before"
        @outletArgs={{hash topic=@topicInfo}}
      />
      <div class={{concatClass (if this.twoRows "two-rows") "extra-info"}}>
        <div class="title-wrapper">
          <h1 class="header-title">
            {{#if this.showPM}}
              <a
                class="private-message-glyph-wrapper"
                href={{this.pmHref}}
                aria-label={{i18n "user.messages.inbox"}}
              >
                {{icon "envelope" class="private-message-glyph"}}
              </a>
            {{/if}}

            {{#if (and @topicInfo.fancyTitle @topicInfo.url)}}
              <Status
                @topicInfo={{@topicInfo}}
                @disableActions={{@disableActions}}
              />

              <a
                class="topic-link"
                {{on "click" this.jumpToTopPost}}
                href={{@topicInfo.url}}
                data-topic-id={{@topicInfo.id}}
              >
                <span>{{htmlSafe @topicInfo.fancyTitle}}</span>
              </a>

              <span class="header-topic-title-suffix">
                <PluginOutlet
                  @name="header-topic-title-suffix"
                  @outletArgs={{hash topic=@topicInfo}}
                />
              </span>
            {{/if}}
          </h1>

          {{#if (or @topicInfo.details.loaded @topicInfo.category)}}
            {{#if
              (and
                @topicInfo.category
                (or
                  (not @topicInfo.category.isUncategorizedCategory)
                  (not this.siteSettings.suppress_uncategorized_badge)
                )
              )
            }}
              <div class="categories-wrapper">
                <PluginOutlet
                  @name="header-categories-wrapper"
                  @outletArgs={{hash category=@topicInfo.category}}
                >
                  {{#if @topicInfo.category.parentCategory}}
                    {{#if
                      (and
                        @topicInfo.category.parentCategory.parentCategory
                        this.site.desktopView
                      )
                    }}
                      {{categoryLink
                        @topicInfo.category.parentCategory.parentCategory
                        (hash hideParent="true")
                      }}
                    {{/if}}

                    {{categoryLink
                      @topicInfo.category.parentCategory
                      (hash hideParent="true")
                    }}
                  {{/if}}
                  {{categoryLink @topicInfo.category (hash hideParent="true")}}
                </PluginOutlet>
              </div>
            {{/if}}

            <div class="topic-header-extra">
              {{htmlSafe this.tags}}
              {{#if this.showPM}}
                <div class="topic-header-participants">
                  {{#each this.participants as |participant|}}
                    <Participant
                      @user={{participant}}
                      @type={{if participant.username "user" "group"}}
                      {{! username for user, name for group }}
                      @username={{or participant.username participant.name}}
                    />
                  {{/each}}

                  {{#if (gt this.totalParticipants this.maxExtraItems)}}
                    <a
                      class="more-participants"
                      {{on "click" this.jumpToTopPost}}
                      href={{@topicInfo.url}}
                      data-topic-id={{@topicInfo.id}}
                    >
                      +{{this.remainingParticipantCount}}
                    </a>
                  {{/if}}
                </div>
              {{/if}}
              {{#if this.siteSettings.topic_featured_link_enabled}}
                <FeaturedLink @topicInfo={{@topicInfo}} />
              {{/if}}
            </div>
          {{/if}}
        </div>
      </div>
      <PluginOutlet
        @name="header-topic-info__after"
        @outletArgs={{hash topic=@topicInfo}}
      />
    </div>
  </template>
}
