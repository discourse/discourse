import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import { gt } from "truth-helpers";
import DButton from "discourse/components/d-button";
import RelativeDate from "discourse/components/relative-date";
import TopicParticipants from "discourse/components/topic-map/topic-participants";
import number from "discourse/helpers/number";
import slice from "discourse/helpers/slice";
import i18n from "discourse-common/helpers/i18n";
import { avatarImg } from "discourse-common/lib/avatar-utils";

export default class TopicMapSummary extends Component {
  get toggleMapButton() {
    return {
      title: this.args.collapsed
        ? "topic.expand_details"
        : "topic.collapse_details",
      icon: this.args.collapsed ? "chevron-down" : "chevron-up",
      ariaExpanded: this.args.collapsed ? "false" : "true",
      ariaControls: "topic-map-expanded",
      action: this.args.toggleMap,
    };
  }

  get shouldShowParticipants() {
    return (
      this.args.collapsed &&
      this.args.postAttrs.topicPostsCount > 2 &&
      this.args.postAttrs.participants &&
      this.args.postAttrs.participants.length > 0
    );
  }

  get createdByAvatar() {
    return htmlSafe(
      avatarImg({
        avatarTemplate: this.args.postAttrs.createdByAvatarTemplate,
        size: "tiny",
        title:
          this.args.postAttrs.createdByName ||
          this.args.postAttrs.createdByUsername,
      })
    );
  }

  get lastPostAvatar() {
    return htmlSafe(
      avatarImg({
        avatarTemplate: this.args.postAttrs.lastPostAvatarTemplate,
        size: "tiny",
        title:
          this.args.postAttrs.lastPostName ||
          this.args.postAttrs.lastPostUsername,
      })
    );
  }

  <template>
    <nav class="buttons">
      <DButton
        @icon={{this.toggleMapButton.icon}}
        @title={{this.toggleMapButton.title}}
        @ariaExpanded={{this.toggleMapButton.ariaExpanded}}
        @ariaControls={{this.toggleMapButton.ariaControls}}
        @action={{this.toggleMapButton.action}}
        class="btn"
      />
    </nav>
    <ul>
      <li class="created-at">
        <h4 role="presentation">{{i18n "created_lowercase"}}</h4>
        <div class="topic-map-post created-at">
          <a
            class="trigger-user-card"
            data-user-card={{@postAttrs.createdByUsername}}
            title={{@postAttrs.createdByUsername}}
            aria-hidden="true"
          />
          {{this.createdByAvatar}}
          <RelativeDate @date={{@postAttrs.topicCreatedAt}} />
        </div>
      </li>
      <li class="last-reply">
        <a href={{@postAttrs.lastPostUrl}}>
          <h4 role="presentation">{{i18n "last_reply_lowercase"}}</h4>
          <div class="topic-map-post last-reply">
            <a
              class="trigger-user-card"
              data-user-card={{@postAttrs.lastPostUsername}}
              title={{@postAttrs.lastPostUsername}}
              aria-hidden="true"
            />
            {{this.lastPostAvatar}}
            <RelativeDate @date={{@postAttrs.lastPostAt}} />
          </div>
        </a>
      </li>
      <li class="replies">
        {{number @postAttrs.topicReplyCount noTitle="true"}}
        <h4 role="presentation">{{i18n
            "replies_lowercase"
            count=@postAttrs.topicReplyCount
          }}</h4>
      </li>
      <li class="secondary views">
        {{number
          @postAttrs.topicViews
          noTitle="true"
          class=@postAttrs.topicViewsHeat
        }}
        <h4 role="presentation">{{i18n
            "views_lowercase"
            count=@postAttrs.topicViews
          }}</h4>
      </li>
      {{#if (gt @postAttrs.participantCount 0)}}
        <li class="secondary users">
          {{number @postAttrs.participantCount noTitle="true"}}
          <h4 role="presentation">{{i18n
              "users_lowercase"
              count=@postAttrs.participantCount
            }}</h4>
        </li>
      {{/if}}
      {{#if (gt @postAttrs.topicLikeCount 0)}}
        <li class="secondary likes">
          {{number @postAttrs.topicLikeCount noTitle="true"}}
          <h4 role="presentation">{{i18n
              "likes_lowercase"
              count=@postAttrs.topicLikeCount
            }}</h4>
        </li>
      {{/if}}
      {{#if (gt @postAttrs.topicLinkCount 0)}}
        <li class="secondary links">
          {{number @postAttrs.topicLinkCount noTitle="true"}}
          <h4 role="presentation">{{i18n
              "links_lowercase"
              count=@postAttrs.topicLinkCount
            }}</h4>
        </li>
      {{/if}}

      {{#if this.shouldShowParticipants}}
        <li class="avatars">
          <TopicParticipants
            @participants={{slice 0 3 @postAttrs.participants}}
            @userFilters={{@postAttrs.userFilters}}
          />
        </li>
      {{/if}}
    </ul>
  </template>
}
