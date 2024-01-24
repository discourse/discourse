import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import RelativeDate from "discourse/components/relative-date";
import TopicParticipants from "discourse/components/topic-map/topic-participants";
import number from "discourse/helpers/number";
import slice from "discourse/helpers/slice";
import i18n from "discourse-common/helpers/i18n";
import { avatarImg } from "discourse-common/lib/avatar-utils";
import gt from "truth-helpers/helpers/gt";


export default class TopicMapSummary extends Component {
  get toggleMapButton() {
    return {
      title: this.args.collapsed ? "topic.expand_details" : "topic.collapse_details",
      icon: this.args.collapsed ? "chevron-down" : "chevron-up",
      ariaExpanded: this.args.collapsed ? "false" : "true",
      ariaControls: "topic-map-expanded",
      action: this.args.toggleMap,
    };
  }

  get shouldShowParticipants() {
    return this.args.collapsed &&
      this.args.topicPostsCount > 2 &&
      this.args.participants &&
      this.args.participants.length > 0;
  }

  get createdByAvatar() {
    return htmlSafe(
      avatarImg({
        avatarTemplate: this.args.createdByAvatarTemplate,
        size: "tiny",
        title: this.args.createdByName || this.args.createdByUsername,
      })
    );
  }

  get lastPostAvatar() {
    return htmlSafe(
      avatarImg({
        avatarTemplate: this.args.lastPostAvatarTemplate,
        size: "tiny",
        title: this.args.lastPostName || this.args.lastPostUsername,
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
            data-user-card={{@createdByUsername}}
            title={{@createdByUsername}}
            aria-hidden="true"
          />
          {{this.createdByAvatar}}
          <RelativeDate @date={{@topicCreatedAt}} />
        </div>
      </li>
      <li class="last-reply">
        <a href={{@lastPostUrl}}>
          <h4 role="presentation">{{i18n "last_reply_lowercase"}}</h4>
          <div class="topic-map-post last-reply">
            <a
              class="trigger-user-card"
              data-user-card={{@lastPostUsername}}
              title={{@lastPostUsername}}
              aria-hidden="true"
            />
            {{this.lastPostAvatar}}
            <RelativeDate @date={{@lastPostAt}} />
          </div>
        </a>
      </li>
      <li class="replies">
        {{number @topicReplyCount noTitle="true"}}
        <h4 role="presentation">{{i18n "replies_lowercase" count=@topicReplyCount}}</h4>
      </li>
      <li class="secondary views">
        {{number @topicViews noTitle="true" class=@topicViewsHeat}}
        <h4 role="presentation">{{i18n "views_lowercase" count=@topicViews}}</h4>
      </li>
      {{#if (gt @participantCount 0)}}
        <li class="secondary users">
          {{number @participantCount noTitle="true"}}
          <h4 role="presentation">{{i18n "users_lowercase" count=@participantCount}}</h4>
        </li>
      {{/if}}
      {{#if (gt @topicLikeCount 0)}}
        <li class="secondary likes">
          {{number @topicLikeCount noTitle="true"}}
          <h4 role="presentation">{{i18n "likes_lowercase" count=@topicLikeCount}}</h4>
        </li>
      {{/if}}
      {{#if (gt @topicLinkCount 0)}}
        <li class="secondary links">
          {{number @topicLinkCount noTitle="true"}}
          <h4 role="presentation">{{i18n "links_lowercase" count=@topicLinkCount}}</h4>
        </li>
      {{/if}}

      {{#if this.shouldShowParticipants}}
        <li class="avatars">
          <TopicParticipants
            @participants={{slice 0 3 @participants}}
            @userFilters={{@userFilters}}
          />
        </li>
      {{/if}}
    </ul>
  </template>
}
