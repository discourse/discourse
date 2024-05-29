import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import { gt } from "truth-helpers";
import DButton from "discourse/components/d-button";
import RelativeDate from "discourse/components/relative-date";
import TopicParticipants from "discourse/components/topic-map/topic-participants";
import number from "discourse/helpers/number";
import slice from "discourse/helpers/slice";
import { avatarImg } from "discourse-common/lib/avatar-utils";
import { i18n } from "discourse-i18n";

export default class TopicMapSummary extends Component {
  get linksCount() {
    return this.args.topicDetails.links?.length ?? 0;
  }

  get createdByUsername() {
    return this.args.topicDetails.created_by?.username;
  }

  get lastPosterUsername() {
    return this.args.topicDetails.last_poster?.username;
  }

  get toggleMapButton() {
    return {
      title: this.args.collapsed
        ? "topic.expand_details"
        : "topic.collapse_details",
      icon: this.args.collapsed ? "chevron-down" : "chevron-up",
      ariaExpanded: this.args.collapsed ? "false" : "true",
      ariaControls: "topic-map-expanded__aria-controls",
      action: this.args.toggleMap,
    };
  }

  get shouldShowParticipants() {
    return (
      this.args.collapsed &&
      this.args.topic.posts_count > 2 &&
      this.args.topicDetails.participants &&
      this.args.topicDetails.participants.length > 0
    );
  }

  get createdByAvatar() {
    return htmlSafe(
      avatarImg({
        avatarTemplate: this.args.topicDetails.created_by?.avatar_template,
        size: "tiny",
        title:
          this.args.topicDetails.created_by?.name ||
          this.args.topicDetails.created_by?.username,
      })
    );
  }

  get lastPostAvatar() {
    return htmlSafe(
      avatarImg({
        avatarTemplate: this.args.topicDetails.last_poster?.avatar_template,
        size: "tiny",
        title:
          this.args.topicDetails.last_poster?.name ||
          this.args.topicDetails.last_poster?.username,
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
            data-user-card={{this.createdByUsername}}
            title={{this.createdByUsername}}
            aria-hidden="true"
          />
          {{this.createdByAvatar}}
          <RelativeDate @date={{@topic.created_at}} />
        </div>
      </li>
      <li class="last-reply">
        <a href={{@topic.lastPostUrl}}>
          <h4 role="presentation">{{i18n "last_reply_lowercase"}}</h4>
          <div class="topic-map-post last-reply">
            <a
              class="trigger-user-card"
              data-user-card={{this.lastPosterUsername}}
              title={{this.lastPosterUsername}}
              aria-hidden="true"
            />
            {{this.lastPostAvatar}}
            <RelativeDate @date={{@topic.last_posted_at}} />
          </div>
        </a>
      </li>
      <li class="replies">
        {{number @topic.replyCount noTitle="true"}}
        <h4 role="presentation">{{i18n
            "replies_lowercase"
            count=@topic.replyCount
          }}</h4>
      </li>
      <li class="secondary views">
        {{number @topic.views noTitle="true" class=@topic.viewsHeat}}
        <h4 role="presentation">{{i18n
            "views_lowercase"
            count=@topic.views
          }}</h4>
      </li>
      {{#if (gt @topic.participant_count 0)}}
        <li class="secondary users">
          {{number @topic.participant_count noTitle="true"}}
          <h4 role="presentation">{{i18n
              "users_lowercase"
              count=@topic.participant_count
            }}</h4>
        </li>
      {{/if}}
      {{#if (gt @topic.like_count 0)}}
        <li class="secondary likes">
          {{number @topic.like_count noTitle="true"}}
          <h4 role="presentation">{{i18n
              "likes_lowercase"
              count=@topic.like_count
            }}</h4>
        </li>
      {{/if}}
      {{#if (gt this.linksCount 0)}}
        <li class="secondary links">
          {{number this.linksCount noTitle="true"}}
          <h4 role="presentation">{{i18n
              "links_lowercase"
              count=this.linksCount
            }}</h4>
        </li>
      {{/if}}

      {{#if this.shouldShowParticipants}}
        <li class="avatars">
          <TopicParticipants
            @participants={{slice 0 3 @topicDetails.participants}}
            @userFilters={{@userFilters}}
          />
        </li>
      {{/if}}
    </ul>
  </template>
}
