import icon from "discourse-common/helpers/d-icon";
import renderTags from "discourse/lib/render-tags";
import { topicFeaturedLinkNode } from "discourse/lib/render-topic-featured-link";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { action } from "@ember/object";
import i18n from "discourse-common/helpers/i18n";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import DiscourseURL from "discourse/lib/url";
import and from "truth-helpers/helpers/and";
import not from "truth-helpers/helpers/not";
import or from "truth-helpers/helpers/or";
import gt from "truth-helpers/helpers/gt";
import gte from "truth-helpers/helpers/gte";
import { htmlSafe } from "@ember/template";
import categoryLink from "discourse/helpers/category-link";
import Participant from "./participant";
import SidebarToggle from "../sidebar-toggle";
import PluginOutlet from "../../plugin-outlet";
import MountWidget from "../../mount-widget";

import Status from "./status";

let _additionalFancyTitleClasses = [];
let _extraInfoComponentsCount;

export function addHeaderFancyTitleClass(className) {
  _additionalFancyTitleClasses.push(className);
}

export default class Info extends Component {
  @service currentUser;
  @service site;
  @service siteSettings;

  constructor() {
    super(...arguments);
    // reset the extra info components count
    _extraInfoComponentsCount = 0;
  }

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
    const extraItems = this.totalParticipants + this.args.topic.tags?.length;
    return extraItems > 0 ? 5 : 10;
  }

  get additionalFancyTitleClasses() {
    return _additionalFancyTitleClasses.join(" ");
  }

  get twoRows() {
    return (
      this.tags?.length ||
      this.showPM ||
      this.siteSettings.topic_featured_link_enabled
    );
  }

  get tags() {
    if (!this.args.topic.tags) {
      return;
    }
    return renderTags(this.args.topic);
  }

  get remainingParticipantCount() {
    return this.totalParticipants - this.maxExtraItems;
  }

  @action
  jumpToTopPost(e) {
    e.preventDefault();
    if (this.args.topic) {
      DiscourseURL.routeTo(this.args.topic.firstPostUrl, {
        keepFilter: true,
      });
    }
  }

  @action
  incrementExtraInfoComponentsCount() {
    _extraInfoComponentsCount++;
  }

  <template>
    <div
      class={{concatClass (if this.twoRows "two-rows") "extra-info-wrapper"}}
    >
      <div class={{concatClass (if this.twoRows "two-rows") "extra-info"}}>
        <div class="title-wrapper">
          <h1 class="header-title">
            {{#if this.showPM}}
              <a
                class="private-message-glyph-wrapper"
                href={{fn this.currentUser.pmPath topic}}
                aria-label={{i18n "user.messages.inbox"}}
              >
                {{icon "envelope" class="private-message-glyph"}}
              </a>
            {{/if}}

            {{#if (and @topic.fancyTitle @topic.url)}}
              <Status @topic={{@topic}} @disableActions={{@disableActions}} />

              <a
                class={{concatClass
                  "topic-link"
                  this.additionalFancyTitleClasses
                }}
                {{on "click" this.jumpToTopPost}}
                href={{@topic.url}}
                data-topic-id={{@topic.id}}
              >
                <span>{{@topic.fancyTitle}}</span>
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
                      (gt this.siteSettings.max_category_nesting 2)
                      (not this.site.mobileView)
                    )
                  }}
                    {{categoryLink @topic.category.parentCategory}}
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
              <div class="topic-header-participants">
                {{#if this.showPM}}
                  {{#each @topic.details.allowed_users as |user|}}
                    {{#unless
                      (gte _extraInfoComponentsCount this.maxExtraItems)
                    }}
                      <Participant
                        @user={{user}}
                        @type="user"
                        @username={{user.username}}
                      />
                      {{this.incrementExtraInfoComponentsCount}}
                    {{/unless}}
                  {{/each}}

                  {{#each @topic.allowed_groups as |group|}}
                    {{#unless
                      (gte _extraInfoComponentsCount this.maxExtraItems)
                    }}
                      <Participant
                        @group={{group}}
                        @type="group"
                        @username={{group.name}}
                      />
                      {{this.incrementExtraInfoComponentsCount}}
                    {{/unless}}
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
                {{/if}}
              </div>
            </div>
          {{/if}}
        </div>
      </div>
    </div>
  </template>
}
