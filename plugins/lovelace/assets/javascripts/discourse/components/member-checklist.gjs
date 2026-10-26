import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { cancel, later } from "@ember/runloop";
import { service } from "@ember/service";
import { ajax, updateCsrfToken } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import { prefersReducedMotion } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";
import { i18n } from "discourse-i18n";

const COMPLETION_DURATION_MS = 3000;

export default class MemberChecklist extends Component {
  @service a11y;
  @service currentUser;
  @service router;
  @service session;
  @service siteSettings;

  @tracked celebrating = false;
  @tracked saving = false;
  confetti = Array.from({ length: 18 }, (_, index) => index);

  #completionTimer;
  #countdownAnimation;
  @tracked _checklist;
  @tracked _dismissing = false;

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.#completionTimer);
    this.#countdownAnimation?.cancel();
  }

  get checklist() {
    return (
      this.args.previewChecklist ??
      this._checklist ??
      this.currentUser?.lovelace_member_checklist
    );
  }

  get visible() {
    return (
      this.siteSettings.lovelace_enabled &&
      this.checklist?.items.length &&
      (!this.checklist.dismissed || this.completing) &&
      (this.args.previewChecklist ||
        !this.router.currentRouteName?.startsWith("admin"))
    );
  }

  get items() {
    return this.checklist.items.map((item) => ({
      ...item,
      href: getURL(item.url),
      complete: this.checklist.completed_ids.includes(item.id),
    }));
  }

  get completing() {
    return this.celebrating && this.allComplete;
  }

  get dismissing() {
    return this._dismissing && this.completing;
  }

  get allComplete() {
    return this.checklist.completed_ids.length === this.checklist.items.length;
  }

  get progress() {
    return i18n("lovelace.onboarding.progress", {
      count: this.checklist.completed_ids.length,
      total: this.checklist.items.length,
    });
  }

  @action
  async recordLinkClick(item, event) {
    if (this.args.previewChecklist) {
      return;
    }
    if (event.type === "auxclick" && event.button !== 1) {
      return;
    }
    try {
      if (!this.session.csrfToken) {
        await updateCsrfToken();
      }
      // Keep the request alive when a link leaves the app without delaying navigation.
      await fetch(getURL("/lovelace/member-checklist.json"), {
        method: "PUT",
        credentials: "same-origin",
        keepalive: true,
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.session.csrfToken,
        },
        body: JSON.stringify({ clicked_item_id: item.id, seen: true }),
      });
    } catch {
      // Reporting failures must not interfere with following a link.
    }
  }

  @action
  async recordSeen() {
    if (this.args.previewChecklist) {
      return;
    }
    try {
      await ajax("/lovelace/member-checklist.json", {
        type: "PUT",
        contentType: "application/json",
        data: JSON.stringify({ seen: true }),
      });
    } catch {
      // A failed impression must not interrupt checklist interactions.
    }
  }

  @action
  startCountdown(element) {
    this.#countdownAnimation?.cancel();
    this.#countdownAnimation = element.animate(
      [{ transform: "scaleX(1)" }, { transform: "scaleX(0)" }],
      {
        duration: COMPLETION_DURATION_MS,
        easing: prefersReducedMotion() ? "steps(3, end)" : "linear",
        fill: "forwards",
      }
    );
  }

  @action
  toggleItem(item) {
    return this.#save({ item_id: item.id, completed: !item.complete });
  }

  @action
  toggleMinimized() {
    return this.#save({ minimized: !this.checklist.minimized });
  }

  @action
  dismiss() {
    if (this.completing) {
      this.#beginDismissal();
      return;
    }
    return this.#save({ dismissed: true });
  }

  #beginDismissal() {
    if (!this.completing || this.dismissing) {
      return;
    }
    cancel(this.#completionTimer);
    this.#countdownAnimation?.pause();
    if (prefersReducedMotion()) {
      this.#finishCompletion();
      return;
    }
    this._dismissing = true;
    // Match the opacity transition in member-checklist.scss.
    this.#completionTimer = later(() => this.#finishCompletion(), 300);
  }

  #finishCompletion() {
    cancel(this.#completionTimer);
    this.#countdownAnimation?.cancel();
    this._dismissing = false;
    this.celebrating = false;
  }

  async #save(data) {
    this.saving = true;
    const wasComplete =
      this.checklist.completed_ids.length === this.checklist.items.length;
    try {
      let checklist;
      if (this.args.previewChecklist) {
        checklist = { ...this.checklist, ...data };
        if (data.item_id) {
          checklist.completed_ids = this.checklist.completed_ids.filter(
            (id) => id !== data.item_id
          );
          if (data.completed) {
            checklist.completed_ids.push(data.item_id);
          }
        }
        if (
          data.completed &&
          checklist.completed_ids.length === checklist.items.length
        ) {
          checklist.dismissed = true;
        }
        this.args.onPreviewChange(checklist);
      } else {
        checklist = await ajax("/lovelace/member-checklist.json", {
          type: "PUT",
          contentType: "application/json",
          data: JSON.stringify({ ...data, seen: true }),
        });
        this._checklist = checklist;
        this.currentUser.set("lovelace_member_checklist", checklist);
      }
      this.celebrating =
        !wasComplete &&
        checklist.completed_ids.length === checklist.items.length;
      cancel(this.#completionTimer);
      this._dismissing = false;
      if (this.celebrating) {
        this.#completionTimer = later(
          () => this.#beginDismissal(),
          COMPLETION_DURATION_MS
        );
      }
      this.a11y.announce(
        this.celebrating ? i18n("lovelace.member.complete") : this.progress
      );
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    {{#if this.visible}}
      <section
        aria-labelledby="lovelace-member-title"
        class={{dConcatClass
          "lovelace-member-checklist"
          (if this.dismissing "--dismissing")
        }}
        ...attributes
        {{didInsert this.recordSeen}}
      >
        <header class="lovelace-member-checklist__header">
          <h2 id="lovelace-member-title">
            {{dIcon "list"}}
            {{i18n "lovelace.checklist"}}
          </h2>
          <DButton
            aria-controls="lovelace-member-items"
            aria-expanded={{if
              (or this.checklist.minimized this.completing)
              "false"
              "true"
            }}
            class="btn-transparent lovelace-member-checklist__minimize"
            @action={{this.toggleMinimized}}
            @disabled={{or this.saving this.completing}}
            @icon={{if this.checklist.minimized "chevron-down" "chevron-up"}}
            @title={{if
              this.checklist.minimized
              "lovelace.member.expand"
              "lovelace.member.minimize"
            }}
          />
          <DButton
            class="btn-transparent lovelace-member-checklist__dismiss"
            @action={{this.dismiss}}
            @disabled={{or this.saving this.dismissing}}
            @icon="xmark"
            @title="lovelace.member.dismiss"
          />
          <label class="lovelace-member-checklist__progress">
            {{this.progress}}
            <progress
              max={{this.checklist.items.length}}
              value={{this.checklist.completed_ids.length}}
            >{{this.progress}}</progress>
          </label>
        </header>
        {{#if this.completing}}
          <p class="lovelace-member-checklist__celebration">{{i18n
              "lovelace.member.complete"
            }}</p>
          <div class="lovelace-member-checklist__completion-actions">
            <DButton
              class="btn-default lovelace-member-checklist__close"
              @action={{this.dismiss}}
              @disabled={{this.dismissing}}
              @label="lovelace.member.dismiss_completion"
              {{dAutoFocus}}
            />
            <div
              aria-hidden="true"
              class="lovelace-member-checklist__countdown"
            >
              <div
                class="lovelace-member-checklist__countdown-bar"
                {{didInsert this.startCountdown}}
              ></div>
            </div>
          </div>
          <div aria-hidden="true" class="lovelace-member-checklist__confetti">
            {{#each this.confetti}}<span></span>{{/each}}
          </div>
        {{/if}}
        <ul
          class="lovelace-member-checklist__items"
          hidden={{or this.checklist.minimized this.completing}}
          id="lovelace-member-items"
        >
          {{#each this.items key="id" as |item|}}
            <li
              class={{dConcatClass
                "lovelace-member-checklist__item"
                (if item.complete "--complete")
              }}
            >
              <DButton
                aria-pressed={{if item.complete "true" "false"}}
                class="btn-transparent lovelace-member-checklist__check"
                @action={{fn this.toggleItem item}}
                @disabled={{this.saving}}
                @icon={{if item.complete "circle-check" "far-circle"}}
                @translatedTitle={{item.title}}
              />
              <strong
                class="lovelace-member-checklist__title"
              >{{item.title}}</strong>
              <p
                class="lovelace-member-checklist__description"
              >{{item.description}}</p>
              <a
                class="btn btn-transparent btn-small btn-link lovelace-member-checklist__action"
                href={{item.href}}
                rel={{if @previewChecklist "noopener noreferrer"}}
                target={{if @previewChecklist "_blank"}}
                {{on "click" (fn this.recordLinkClick item)}}
                {{on "auxclick" (fn this.recordLinkClick item)}}
              >{{item.button_text}}</a>
            </li>
          {{/each}}
        </ul>
      </section>
    {{/if}}
  </template>
}
