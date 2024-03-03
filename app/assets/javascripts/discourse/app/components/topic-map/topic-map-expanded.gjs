import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import TopicParticipants from "discourse/components/topic-map/topic-participants";
import replaceEmoji from "discourse/helpers/replace-emoji";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import and from "truth-helpers/helpers/and";
import lt from "truth-helpers/helpers/lt";
import not from "truth-helpers/helpers/not";

export default class TopicMapExpanded extends Component {
  @tracked allLinksShown = false;
  truncatedLinksLimit = 5;

  @action
  showAllLinks() {
    this.allLinksShown = true;
  }

  //TODO: refactor TopicParticipants to take i18n string and pass that within a h3 heading if title exists
  get participantsTitle() {
    return htmlSafe(`<h3>${I18n.t("topic_map.participants_title")}</h3>`);
  }

  get linksToShow() {
    return this.allLinksShown
      ? this.args.postAttrs.topicLinks
      : this.args.postAttrs.topicLinks.slice(0, this.truncatedLinksLimit);
  }

  <template>
    {{#if @postAttrs.participants}}
      <section class="avatars">
        <TopicParticipants
          @title={{this.participantsTitle}}
          @userFilters={{@postAttrs.userFilters}}
          @participants={{@postAttrs.participants}}
        />
      </section>
    {{/if}}
    {{#if @postAttrs.topicLinks}}
      <section class="links">
        <h3>{{i18n "topic_map.links_title"}}</h3>
        <table class="topic-links">
          {{#each this.linksToShow as |link|}}
            <tr>
              <td>
                <span
                  class="badge badge-notification clicks"
                  title={{i18n "topic_map.clicks" count=link.clicks}}
                >
                  {{link.clicks}}
                </span>
              </td>
              <td>
                <TopicMapLink
                  @attachment={{link.attachment}}
                  @title={{link.title}}
                  @rootDomain={{link.root_domain}}
                  @url={{link.url}}
                  @userId={{link.user_id}}
                />
              </td>
            </tr>
          {{/each}}
        </table>
        {{#if
          (and
            (not this.allLinksShown)
            (lt this.truncatedLinksLimit @postAttrs.topicLinks.length)
          )
        }}
          <div class="link-summary">
            <span>
              <DButton
                @action={{this.showAllLinks}}
                @title="topic_map.links_shown"
                @icon="chevron-down"
                class="btn-flat"
              />
            </span>
          </div>
        {{/if}}
      </section>
    {{/if}}
  </template>
}

class TopicMapLink extends Component {
  get linkClasses() {
    return this.args.attachment
      ? "topic-link track-link attachment"
      : "topic-link track-link";
  }

  get truncatedContent() {
    const truncateLength = 85;
    const content = this.args.title || this.args.url;
    return content.length > truncateLength
      ? `${content.slice(0, truncateLength).trim()}...`
      : content;
  }

  <template>
    <a
      class={{this.linkClasses}}
      href={{@url}}
      title={{@url}}
      data-user-id={{@userId}}
      data-ignore-post-id="true"
      target="_blank"
      rel="nofollow ugc noopener"
    >
      {{#if @title}}
        {{replaceEmoji this.truncatedContent}}
      {{else}}
        {{this.truncatedContent}}
      {{/if}}
    </a>
    {{#if (and @title @rootDomain)}}
      <span class="domain">
        {{@rootDomain}}
      </span>
    {{/if}}
  </template>
}
