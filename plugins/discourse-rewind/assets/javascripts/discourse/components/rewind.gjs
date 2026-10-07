import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { getAbsoluteURL } from "discourse/lib/get-url";
import { clipboardCopy } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import { i18n } from "discourse-i18n";
import ActivityCalendar from "discourse/plugins/discourse-rewind/discourse/components/reports/activity-calendar";
import AiUsage from "discourse/plugins/discourse-rewind/discourse/components/reports/ai-usage";
import Assignments from "discourse/plugins/discourse-rewind/discourse/components/reports/assignments";
import BestPosts from "discourse/plugins/discourse-rewind/discourse/components/reports/best-posts";
import BestTopics from "discourse/plugins/discourse-rewind/discourse/components/reports/best-topics";
import ChatUsage from "discourse/plugins/discourse-rewind/discourse/components/reports/chat-usage";
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

const REPORT_COMPONENTS = {
  "activity-calendar": ActivityCalendar,
  "ai-usage": AiUsage,
  assignments: Assignments,
  "best-posts": BestPosts,
  "best-topics": BestTopics,
  "chat-usage": ChatUsage,
  fbff: FBFF,
  invites: Invites,
  "most-viewed-categories": MostViewedCategories,
  "most-viewed-tags": MostViewedTags,
  "new-user-interactions": NewUserInteractions,
  reactions: Reactions,
  "reading-time": ReadingTime,
  "time-of-day-activity": TimeOfDayActivity,
  "top-words": TopWords,
  "writing-analysis": WritingAnalysis,
};

export default class Rewind extends Component {
  @service currentUser;
  @service dialog;
  @service toasts;

  @tracked cannotViewRewind = false;
  @tracked fullScreen = true;
  @tracked isLoadingMore = false;
  @tracked loadingRewind = false;
  @tracked nextOffset = 0;
  @tracked rewind = [];
  @tracked scrollWrapper = null;
  @tracked totalAvailable = 0;

  registerScrollWrapper = modifier((element) => {
    this.scrollWrapper = element;
    return () => (this.scrollWrapper = null);
  });

  get isOwnRewind() {
    return this.currentUser.id === this.args.user.id;
  }

  get #userParams() {
    return this.isOwnRewind
      ? {}
      : { for_user_username: this.args.user.username };
  }

  get hasMoreReports() {
    return this.nextOffset < this.totalAvailable;
  }

  @action
  async loadRewind() {
    try {
      this.loadingRewind = true;
      await this.#loadReports();
    } catch (err) {
      if (err.jqXHR?.status === 404 || err.jqXHR?.status === 403) {
        this.cannotViewRewind = true;
      } else {
        popupAjaxError(err);
      }
    } finally {
      this.loadingRewind = false;
    }
  }

  @action
  async loadMoreReports() {
    if (this.isLoadingMore) {
      return;
    }

    this.isLoadingMore = true;

    try {
      await this.#loadReports();
    } catch (err) {
      this.totalAvailable = this.nextOffset;
      popupAjaxError(err);
    } finally {
      this.isLoadingMore = false;
    }
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
      await this.#toggleShare("discourse_rewind.share.disabled_success");
      return;
    }

    await this.dialog.confirm({
      message: i18n("discourse_rewind.share.confirm"),
      confirmButtonLabel: "discourse_rewind.share.confirm_button.enable",
      cancelButtonLabel: "discourse_rewind.share.confirm_button.disable",
      didConfirm: () =>
        this.#toggleShare("discourse_rewind.share.enabled_success"),
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

  async #loadReports() {
    const response = await ajax("/rewinds.json", {
      data: { ...this.#userParams, offset: this.nextOffset },
    });
    this.rewind = [...this.rewind, ...response.reports.filter(Boolean)];
    this.totalAvailable = response.total_available;
    this.nextOffset += response.reports.length;
  }

  async #toggleShare(successMessageKey) {
    try {
      const response = await ajax("/rewinds/toggle-share", { type: "PUT" });
      this.currentUser.set(
        "user_option.discourse_rewind_share_publicly",
        response.shared
      );
      this.toasts.success({
        duration: "short",
        data: { message: i18n(successMessageKey) },
      });
    } catch (err) {
      popupAjaxError(err);
    }
  }

  <template>
    <div
      class={{dConcatClass
        "rewind-container"
        (if this.fullScreen "--fullscreen")
      }}
      tabindex="0"
      {{didInsert this.loadRewind}}
      {{on "keydown" this.handleEscape}}
      {{on "click" this.handleBackdropClick}}
    >
      <div class="rewind">
        <RewindHeader />
        {{#if this.loadingRewind}}
          <div class="rewind-loader">
            {{dLoadingSpinner size="small"}}
            <div class="rewind-loader__text">
              {{i18n "discourse_rewind.loading"}}
            </div>
          </div>
        {{else}}
          <div class="rewind__header-buttons">
            {{#if this.isOwnRewind}}
              <div class="rewind__share-toggle-wrapper">
                {{i18n "discourse_rewind.share.toggle_label.private"}}

                <DToggleSwitch
                  class="rewind__share-toggle"
                  @state={{this.currentUser.user_option.discourse_rewind_share_publicly}}
                  {{on "click" this.toggleShareRewind}}
                />
                {{i18n "discourse_rewind.share.toggle_label.public"}}
              </div>

              {{#if
                this.currentUser.user_option.discourse_rewind_share_publicly
              }}
                <DButton
                  class="btn-default rewind__copy-link-btn --special-kbd"
                  @action={{this.copyRewindLink}}
                  @icon="link"
                  @title="composer.link_toolbar.copy"
                />
              {{/if}}
            {{/if}}
            <DButton
              class="btn-default rewind__exit-fullscreen-btn --special-kbd"
              @action={{this.toggleFullScreen}}
              @icon={{if
                this.fullScreen
                "discourse-compress"
                "discourse-expand"
              }}
            />

          </div>

          <div class="rewind__scroll-wrapper" {{this.registerScrollWrapper}}>
            {{#unless this.isOwnRewind}}
              <p class="rewind-other-user">{{trustHTML
                  (i18n
                    "discourse_rewind.viewing_other_user"
                    username=@user.username
                  )
                }}</p>
            {{/unless}}

            {{#if this.cannotViewRewind}}
              <div class="rewind-error">
                <div class="rewind-gibberish">
                  <p class="rewind-gibberish__title">[ACCESS DENIED::REWIND
                    MAINFRAME SUBROUTINE FAILURE]</p>
                  <p>Bootstrapping anomaly log...</p>

                  <p><span class="rewind-gibberish__code-line">>> quantum buffer
                      underrun ⧛</span><br />
                    <span class="rewind-gibberish__code-line">>> cross-node
                      parity drift (Δ=004.33)</span><br />
                    <span class="rewind-gibberish__code-line">>> packet ϟ
                      fragment at offset ∇47</span><br />
                    <span class="rewind-gibberish__code-line">>> flux conduit
                      handshake TIMED OUT</span><br /></p>
                </div>
                {{trustHTML (i18n "discourse_rewind.cannot_view_rewind")}}
              </div>
            {{/if}}

            {{#each this.rewind as |report|}}
              {{#let
                (get REPORT_COMPONENTS report.identifier)
                as |ReportComponent|
              }}
                {{#if ReportComponent}}
                  <div class={{dConcatClass "rewind-report" report.identifier}}>
                    <ReportComponent
                      @isOwnRewind={{this.isOwnRewind}}
                      @report={{report}}
                      @user={{@user}}
                    />
                  </div>
                {{/if}}
              {{/let}}
            {{/each}}

            <DLoadMore
              @action={{this.loadMoreReports}}
              @enabled={{this.hasMoreReports}}
              @isLoading={{this.isLoadingMore}}
              @root={{this.scrollWrapper}}
            />

            {{#if this.isLoadingMore}}
              <div class="rewind-loader --more">
                {{dLoadingSpinner size="small"}}
              </div>
            {{/if}}
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
