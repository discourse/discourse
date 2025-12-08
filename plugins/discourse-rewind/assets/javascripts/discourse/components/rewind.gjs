import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import ActivityCalendar from "discourse/plugins/discourse-rewind/discourse/components/reports/activity-calendar";
import AiUsage from "discourse/plugins/discourse-rewind/discourse/components/reports/ai-usage";
import Assignments from "discourse/plugins/discourse-rewind/discourse/components/reports/assignments";
import BestPosts from "discourse/plugins/discourse-rewind/discourse/components/reports/best-posts";
import BestTopics from "discourse/plugins/discourse-rewind/discourse/components/reports/best-topics";
import ChatUsage from "discourse/plugins/discourse-rewind/discourse/components/reports/chat-usage";
// import FavoriteGifs from "discourse/plugins/discourse-rewind/discourse/components/reports/favorite-gifs";
import FBFF from "discourse/plugins/discourse-rewind/discourse/components/reports/fbff";
import RewindHeader from "discourse/plugins/discourse-rewind/discourse/components/reports/header";
import Invites from "discourse/plugins/discourse-rewind/discourse/components/reports/invites";
import MostViewedCategories from "discourse/plugins/discourse-rewind/discourse/components/reports/most-viewed-categories";
import MostViewedTags from "discourse/plugins/discourse-rewind/discourse/components/reports/most-viewed-tags";
import NewUserInteractions from "discourse/plugins/discourse-rewind/discourse/components/reports/new-user-interactions";
import Reactions from "discourse/plugins/discourse-rewind/discourse/components/reports/reactions";
import ReadingTime from "discourse/plugins/discourse-rewind/discourse/components/reports/reading-time";
import TimeOfDayActivity from "discourse/plugins/discourse-rewind/discourse/components/reports/time-of-day-activity";
import TopWords from "discourse/plugins/discourse-rewind/discourse/components/reports/top-words";
import WritingAnalysis from "discourse/plugins/discourse-rewind/discourse/components/reports/writing-analysis";

export default class Rewind extends Component {
  @tracked rewind = [];
  @tracked fullScreen = true;
  @tracked loadingRewind = false;

  @action
  registerScrollWrapper(element) {
    this.scrollWrapper = element;
  }

  @action
  async loadRewind() {
    try {
      this.loadingRewind = true;
      this.rewind = await ajax("/rewinds");
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingRewind = false;
    }
  }

  @action
  toggleFullScreen() {
    this.fullScreen = !this.fullScreen;
  }

  @action
  handleEscape(event) {
    if (this.fullScreen && event.key === "Escape") {
      this.fullScreen = false;
    }
  }

  @action
  handleBackdropClick(event) {
    if (this.fullScreen && event.target === event.currentTarget) {
      this.fullScreen = false;
    }
  }

  @action
  registerRewindContainer(element) {
    this.rewindContainer = element;
  }

  getReportComponent(identifier) {
    switch (identifier) {
      case "fbff":
        return FBFF;
      case "reactions":
        return Reactions;
      case "top-words":
        return TopWords;
      case "best-posts":
        return BestPosts;
      case "best-topics":
        return BestTopics;
      case "activity-calendar":
        return ActivityCalendar;
      case "most-viewed-tags":
        return MostViewedTags;
      case "reading-time":
        return ReadingTime;
      case "most-viewed-categories":
        return MostViewedCategories;
      case "ai-usage":
        return AiUsage;
      case "assignments":
        return Assignments;
      case "chat-usage":
        return ChatUsage;
      // case "favorite-gifs":
      //   return FavoriteGifs;
      case "invites":
        return Invites;
      case "new-user-interactions":
        return NewUserInteractions;
      case "time-of-day-activity":
        return TimeOfDayActivity;
      case "writing-analysis":
        return WritingAnalysis;
      default:
        return null;
    }
  }

  <template>
    <div
      class={{concatClass
        "rewind-container"
        (if this.fullScreen "--fullscreen")
      }}
      {{didInsert this.loadRewind}}
      {{on "keydown" this.handleEscape}}
      {{on "click" this.handleBackdropClick}}
      {{didInsert this.registerRewindContainer}}
      tabindex="0"
    >
      <div class="rewind">
        <RewindHeader />
        {{#if this.loadingRewind}}
          <div class="rewind-loader">
            <div class="spinner small"></div>
            <div class="rewind-loader__text">
              {{i18n "discourse_rewind.loading"}}
            </div>
          </div>
        {{else}}
          <DButton
            class="btn-default rewind__exit-fullscreen-btn --special-kbd"
            @icon={{if this.fullScreen "discourse-compress" "discourse-expand"}}
            @action={{this.toggleFullScreen}}
          />
          <div
            class="rewind__scroll-wrapper"
            {{didInsert this.registerScrollWrapper}}
          >

            {{#each this.rewind as |report|}}
              {{#let
                (this.getReportComponent report.identifier)
                as |ReportComponent|
              }}
                {{#if ReportComponent}}
                  <div class={{concatClass "rewind-report" report.identifier}}>
                    <ReportComponent @report={{report}} />
                  </div>
                {{/if}}
              {{/let}}
            {{/each}}
          </div>

          {{#if this.showPrev}}
            <DButton
              class="rewind__prev-btn"
              @icon="chevron-left"
              @action={{this.prev}}
            />
          {{/if}}

          {{#if this.showNext}}
            <DButton
              class="rewind__next-btn"
              @icon="chevron-right"
              @action={{this.next}}
            />
          {{/if}}
        {{/if}}
      </div>
    </div>
  </template>
}
