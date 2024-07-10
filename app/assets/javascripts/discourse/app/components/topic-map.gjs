import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import PrivateMessageMap from "discourse/components/topic-map/private-message-map";
import TopicMapExpanded from "discourse/components/topic-map/topic-map-expanded";
import TopicMapSummary from "discourse/components/topic-map/topic-map-summary";
import concatClass from "discourse/helpers/concat-class";
import I18n from "discourse-i18n";

const MIN_POST_READ_TIME = 4;

export default class TopicMap extends Component {
  @service siteSettings;
  @tracked collapsed = !this.args.model.has_summary;

  get userFilters() {
    return this.args.postStream.userFilters || [];
  }

  @action
  toggleMap() {
    this.collapsed = !this.collapsed;
  }

  get topRepliesSummaryInfo() {
    if (this.topRepliesSummaryEnabled) {
      return I18n.t("summary.enabled_description");
    }

    const wordCount = this.args.model.word_count;
    if (wordCount && this.siteSettings.read_time_word_count > 0) {
      const readingTime = Math.ceil(
        Math.max(
          wordCount / this.siteSettings.read_time_word_count,
          (this.args.model.posts_count * MIN_POST_READ_TIME) / 60
        )
      );
      return I18n.messageFormat("summary.description_time_MF", {
        replyCount: this.args.model.replyCount,
        readingTime,
      });
    }
    return I18n.t("summary.description", {
      count: this.args.model.replyCount,
    });
  }

  get topRepliesTitle() {
    if (this.topRepliesSummaryEnabled) {
      return;
    }

    return I18n.t("summary.short_title");
  }

  get topRepliesLabel() {
    const label = this.topRepliesSummaryEnabled
      ? "summary.disable"
      : "summary.enable";

    return I18n.t(label);
  }

  get topRepliesIcon() {
    if (this.topRepliesSummaryEnabled) {
      return;
    }

    return "layer-group";
  }

  <template>
    <section class={{concatClass "map" (if this.collapsed "map-collapsed")}}>
      <TopicMapSummary
        @topic={{@model}}
        @topicDetails={{@topicDetails}}
        @toggleMap={{this.toggleMap}}
        @collapsed={{this.collapsed}}
        @userFilters={{this.userFilters}}
      />
    </section>
    {{#unless this.collapsed}}
      <section
        class="topic-map-expanded"
        id="topic-map-expanded__aria-controls"
      >
        <TopicMapExpanded
          @topicDetails={{@topicDetails}}
          @userFilters={{this.userFilters}}
        />
      </section>
    {{/unless}}

    <section class="information toggle-summary">
      {{#if @model.has_summary}}
        <p>{{htmlSafe this.topRepliesSummaryInfo}}</p>
      {{/if}}
      <PluginOutlet
        @name="topic-map-expanded-after"
        @defaultGlimmer={{true}}
        @outletArgs={{hash topic=@model postStream=@postStream}}
      >
        {{#if @model.has_summary}}
          <DButton
            @action={{if @postStream.summary @cancelFilter @showTopReplies}}
            @translatedTitle={{this.topRepliesTitle}}
            @translatedLabel={{this.topRepliesLabel}}
            @icon={{this.topRepliesIcon}}
            class="top-replies"
          />
        {{/if}}
      </PluginOutlet>
    </section>

    {{#if @showPMMap}}
      <section class="information private-message-map">
        <PrivateMessageMap
          @topicDetails={{@topicDetails}}
          @showInvite={{@showInvite}}
          @removeAllowedGroup={{@removeAllowedGroup}}
          @removeAllowedUser={{@removeAllowedUser}}
        />
      </section>
    {{/if}}
  </template>
}
