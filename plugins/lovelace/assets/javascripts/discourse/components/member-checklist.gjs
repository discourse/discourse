import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class MemberChecklist extends Component {
  @service a11y;
  @service currentUser;
  @service router;
  @service siteSettings;

  @tracked celebrating = false;
  @tracked saving = false;
  confetti = Array.from({ length: 18 }, (_, index) => index);

  @tracked _checklist;

  get checklist() {
    return this._checklist ?? this.currentUser?.lovelace_member_checklist;
  }

  get visible() {
    return (
      this.siteSettings.lovelace_enabled &&
      this.checklist?.items.length &&
      !this.checklist.dismissed &&
      !this.router.currentRouteName?.startsWith("admin")
    );
  }

  get items() {
    return this.checklist.items.map((item) => ({
      ...item,
      href: getURL(item.url),
      complete: this.checklist.completed_ids.includes(item.id),
    }));
  }

  get progress() {
    return i18n("lovelace.onboarding.progress", {
      count: this.checklist.completed_ids.length,
      total: this.checklist.items.length,
    });
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
    return this.#save({ dismissed: true });
  }

  async #save(data) {
    this.saving = true;
    const wasComplete =
      this.checklist.completed_ids.length === this.checklist.items.length;
    try {
      const checklist = await ajax("/lovelace/member-checklist.json", {
        type: "PUT",
        contentType: "application/json",
        data: JSON.stringify(data),
      });
      this._checklist = checklist;
      this.currentUser.set("lovelace_member_checklist", checklist);
      this.celebrating =
        !wasComplete &&
        checklist.completed_ids.length === checklist.items.length;
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
        class="lovelace-member-checklist"
        ...attributes
      >
        <header class="lovelace-member-checklist__header">
          <h2 id="lovelace-member-title">
            {{dIcon "list"}}
            {{i18n "lovelace.checklist"}}
          </h2>
          <DButton
            aria-controls="lovelace-member-items"
            aria-expanded={{if this.checklist.minimized "false" "true"}}
            class="btn-transparent lovelace-member-checklist__minimize"
            @action={{this.toggleMinimized}}
            @disabled={{this.saving}}
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
            @disabled={{this.saving}}
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
        {{#if this.celebrating}}
          <p class="lovelace-member-checklist__celebration">{{i18n
              "lovelace.member.complete"
            }}</p>
          <div aria-hidden="true" class="lovelace-member-checklist__confetti">
            {{#each this.confetti}}<span></span>{{/each}}
          </div>
        {{/if}}
        <ul
          class="lovelace-member-checklist__items"
          hidden={{this.checklist.minimized}}
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
              >{{item.button_text}}</a>
            </li>
          {{/each}}
        </ul>
      </section>
    {{/if}}
  </template>
}
