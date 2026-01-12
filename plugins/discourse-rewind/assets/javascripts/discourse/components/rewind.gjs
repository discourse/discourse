import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { getAbsoluteURL } from "discourse/lib/get-url";
import { clipboardCopy } from "discourse/lib/utilities";
import { eq } from "discourse/truth-helpers";
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

const BUFFER_SIZE = 3;
const SCROLL_THRESHOLD = 0.7;

export default class Rewind extends Component {
  @service dialog;
  @service currentUser;
  @service toasts;

  @tracked rewind = [];
  @tracked fullScreen = this.currentUser !== null;
  @tracked loadingRewind = false;
  @tracked totalAvailable = 0;
  @tracked isLoadingMore = false;
  @tracked cannotViewRewind = false;
  nextReportIndex = 0;

  get canShare() {
    return this.currentUser.id === this.args.user.id;
  }

  get isOwnRewind() {
    return this.currentUser?.id === this.args.user.id;
  }

  @action
  registerScrollWrapper(element) {
    this.scrollWrapper = element;
    this.scrollWrapper.addEventListener("scroll", this.handleScroll);
  }

  @action
  cleanup() {
    this.scrollWrapper?.removeEventListener("scroll", this.handleScroll);
  }

  @action
  async loadRewind() {
    let url = "/rewinds.json";
    if (this.args.user.id !== this.currentUser.id) {
      url += `?for_user_username=${this.args.user.username}`;
    }

    try {
      this.loadingRewind = true;
      const response = await ajax(url);
      this.rewind = response.reports;
      this.totalAvailable = response.total_available;
      this.nextReportIndex = response.reports.length;
    } catch (err) {
      if (err.jqXHR.status === 404 || err.jqXHR.status === 403) {
        this.cannotViewRewind = true;
      } else {
        popupAjaxError(err);
      }
    } finally {
      this.loadingRewind = false;
    }

    // Load more if content fits on screen without scrolling
    this.checkIfMoreContentNeeded();
  }

  checkIfMoreContentNeeded() {
    if (!this.scrollWrapper || this.nextReportIndex >= this.totalAvailable) {
      return;
    }

    const { scrollHeight, clientHeight } = this.scrollWrapper;
    if (scrollHeight <= clientHeight) {
      this.preloadNextReports();
    }
  }

  @action
  handleScroll() {
    if (this.isLoadingMore || this.nextReportIndex >= this.totalAvailable) {
      return;
    }

    const { scrollTop, scrollHeight, clientHeight } = this.scrollWrapper;
    const scrollProgress = (scrollTop + clientHeight) / scrollHeight;

    if (scrollProgress > SCROLL_THRESHOLD) {
      this.preloadNextReports();
    }
  }

  async preloadNextReports() {
    if (this.nextReportIndex >= this.totalAvailable) {
      return;
    }

    const targetIndex = Math.min(
      this.nextReportIndex + BUFFER_SIZE,
      this.totalAvailable
    );

    this.isLoadingMore = true;

    try {
      while (this.nextReportIndex < targetIndex) {
        let url = `/rewinds/${this.nextReportIndex}.json`;
        if (this.args.user.id !== this.currentUser.id) {
          url += `?for_user_username=${this.args.user.username}`;
        }

        try {
          const response = await ajax(url, {
            ignoreUnsent: false,
          });
          if (response.report) {
            this.rewind = [...this.rewind, response.report];
          }
        } catch {
          // Skip failed reports and continue loading
        }
        this.nextReportIndex++;
      }
    } finally {
      this.isLoadingMore = false;
    }

    // Re-check in case we need more content (failed reports or content fits on screen)
    this.checkIfMoreContentNeeded();
  }

  @action
  toggleFullScreen() {
    this.fullScreen = !this.fullScreen;
  }

  @action
  async copyRewindLink() {
    await clipboardCopy(
      getAbsoluteURL(`/u/${this.args.user.username}/activity/rewind`)
    );
    this.toasts.success({
      duration: "short",
      data: {
        message: i18n("post.controls.link_copied"),
      },
    });
  }

  @action
  async toggleShareRewind() {
    if (this.currentUser.user_option.discourse_rewind_share_publicly) {
      try {
        const response = await ajax("/rewinds/toggle-share", {
          type: "PUT",
        });

        this.currentUser.set(
          "user_option.discourse_rewind_share_publicly",
          response.shared
        );

        this.toasts.success({
          duration: "short",
          data: {
            message: i18n("discourse_rewind.share.disabled_success"),
          },
        });
      } catch (err) {
        popupAjaxError(err);
        return;
      }

      return;
    }

    await this.dialog.confirm({
      message: i18n("discourse_rewind.share.confirm"),
      confirmButtonLabel: "discourse_rewind.share.confirm_button.enable",
      cancelButtonLabel: "discourse_rewind.share.confirm_button.disable",
      didConfirm: async () => {
        try {
          const response = await ajax("/rewinds/toggle-share", {
            type: "PUT",
          });
          this.currentUser.set(
            "user_option.discourse_rewind_share_publicly",
            response.shared
          );

          this.toasts.success({
            duration: "short",
            data: {
              message: i18n("discourse_rewind.share.enabled_success"),
            },
          });
        } catch (err) {
          popupAjaxError(err);
        }
      },
    });
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
          <div class="rewind__header-buttons">
            {{#if this.canShare}}
              <div class="rewind__share-toggle-wrapper">
                {{i18n "discourse_rewind.share.toggle_label.private"}}

                <DToggleSwitch
                  @state={{this.currentUser.user_option.discourse_rewind_share_publicly}}
                  class="rewind__share-toggle"
                  {{on "click" this.toggleShareRewind}}
                />
                {{i18n "discourse_rewind.share.toggle_label.public"}}
              </div>

              {{#if
                this.currentUser.user_option.discourse_rewind_share_publicly
              }}
                <DButton
                  class="btn-default rewind__copy-link-btn --special-kbd"
                  @title="composer.link_toolbar.copy"
                  @icon="link"
                  @action={{this.copyRewindLink}}
                />
              {{/if}}
            {{/if}}
            <DButton
              class="btn-default rewind__exit-fullscreen-btn --special-kbd"
              @icon={{if
                this.fullScreen
                "discourse-compress"
                "discourse-expand"
              }}
              @action={{this.toggleFullScreen}}
            />

          </div>

          <div
            class="rewind__scroll-wrapper"
            {{didInsert this.registerScrollWrapper}}
            {{willDestroy this.cleanup}}
          >
            {{#unless (eq this.currentUser.id @user.id)}}
              <p class="rewind-other-user">{{htmlSafe
                  (i18n
                    "discourse_rewind.viewing_other_user"
                    username=@user.username
                  )
                }}</p>
            {{/unless}}

            {{#if this.cannotViewRewind}}
              <div class="rewind-error">
                {{htmlSafe
                  (i18n "discourse_rewind.cannot_view_rewind_gibberish")
                }}
                {{htmlSafe (i18n "discourse_rewind.cannot_view_rewind")}}
              </div>
            {{/if}}

            {{#each this.rewind as |report|}}
              {{#let
                (this.getReportComponent report.identifier)
                as |ReportComponent|
              }}
                {{#if ReportComponent}}
                  <div class={{concatClass "rewind-report" report.identifier}}>
                    <ReportComponent
                      @report={{report}}
                      @user={{@user}}
                      @isOwnRewind={{this.isOwnRewind}}
                    />
                  </div>
                {{/if}}
              {{/let}}
            {{/each}}

            {{#if this.isLoadingMore}}
              <div class="rewind-loader --more">
                <div class="spinner small"></div>
              </div>
            {{/if}}
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
