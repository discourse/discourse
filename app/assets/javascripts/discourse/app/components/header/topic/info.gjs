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
import i18n from "discourse-common/helpers/i18n";
import PluginOutlet from "../../plugin-outlet";
import FeaturedLink from "./featured-link";
import Participant from "./participant";
import Status from "./status";

export default class Info extends Component {
  @service currentUser;
  @service site;
  @service siteSettings;

  get showPM() {
    return !this.args.topic.is_warning && this.args.topic.isPrivateMessage;
  }

  get totalParticipants() {
    return (
      (this.args.topic.details.allowed_users?.length || 0) +
      (this.args.topic.allowed_groups?.length || 0)
    );
  }

  get maxExtraItems() {
    return this.args.topic.tags?.length > 0 ? 5 : 10;
  }

  get twoRows() {
    return (
      this.tags?.length ||
      this.showPM ||
      this.siteSettings.topic_featured_link_enabled
    );
  }

  get tags() {
    if (this.args.topic.tags) {
      return renderTags(this.args.topic);
    }
  }

  get remainingParticipantCount() {
    return this.totalParticipants - this.maxExtraItems;
  }

  get participants() {
    const participants = [
      ...this.args.topic.details.allowed_users,
      ...this.args.topic.details.allowed_groups,
    ];
    return participants.slice(0, this.maxExtraItems);
  }

  get pmHref() {
    return this.currentUser.pmPath(this.args.topic);
  }

  @action
  jumpToTopPost(e) {
    if (wantsNewWindow(e)) {
      return;
    }

    e.preventDefault();
    if (this.args.topic) {
      DiscourseURL.routeTo(this.args.topic.firstPostUrl, {
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
        @outletArgs={{hash topic=@topic}}
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

            {{#if (and @topic.fancyTitle @topic.url)}}
              <Status @topic={{@topic}} @disableActions={{@disableActions}} />

              <a
                class="topic-link"
                {{on "click" this.jumpToTopPost}}
                href={{@topic.url}}
                data-topic-id={{@topic.id}}
              >
                <span>{{htmlSafe @topic.fancyTitle}}</span>
              </a>

              <span class="header-topic-title-suffix">
                <PluginOutlet
                  @name="header-topic-title-suffix"
                  @outletArgs={{hash topic=@topic}}
                />
              </span>
            {{/if}}
          </h1>

          {{#if (or @topic.details.loaded @topic.category)}}
            {{#if
              (and
                @topic.category
                (or
                  (not @topic.category.isUncategorizedCategory)
                  (not this.siteSettings.suppress_uncategorized_badge)
                )
              )
            }}
              <div class="categories-wrapper">
                {{#if @topic.category.parentCategory}}
                  {{#if
                    (and
                      @topic.category.parentCategory.parentCategory
                      this.site.desktopView
                    )
                  }}
                    {{categoryLink
                      @topic.category.parentCategory.parentCategory
                    }}
                  {{/if}}

                  {{categoryLink
                    @topic.category.parentCategory
                    (hash hideParent="true")
                  }}
                {{/if}}
                {{categoryLink @topic.category}}
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
                      href={{@topic.url}}
                      data-topic-id={{@topic.id}}
                    >
                      +{{this.remainingParticipantCount}}
                    </a>
                  {{/if}}
                </div>
              {{/if}}
              {{#if this.siteSettings.topic_featured_link_enabled}}
                <FeaturedLink />
              {{/if}}
            </div>
          {{/if}}
        </div>
      </div>
      <PluginOutlet
        @name="header-topic-info__after"
        @outletArgs={{hash topic=@topic}}
      />
    </div>
  </template>
}
