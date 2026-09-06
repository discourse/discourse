import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import UsersPopup from "discourse/components/user/users-popup";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import { i18n } from "discourse-i18n";

const FILTER_SCROLL_PADDING = 8;

export default class ChatMessageReactionsUsers extends Component {
  @service chatApi;

  // The reaction whose menu was opened starts as the active filter. The header
  // tabs let the user switch between the message's reactions within the popup.
  @tracked activeFilter = this.args.data.emoji ?? null;

  // On desktop, report pointer enter/leave on the whole menu so the reaction can
  // keep the hover-to-open popup alive while it (or the reaction) is hovered.
  trackPointerForClose = modifier((element) => {
    const onEnter = this.args.data.onContentPointerEnter;
    const onLeave = this.args.data.onContentPointerLeave;
    if (!onEnter || !onLeave) {
      return;
    }

    const target = element.closest(".fk-d-menu") ?? element;
    target.addEventListener("pointerenter", onEnter, { passive: true });
    target.addEventListener("pointerleave", onLeave, { passive: true });

    return () => {
      target.removeEventListener("pointerenter", onEnter);
      target.removeEventListener("pointerleave", onLeave);
    };
  });

  // Keeps the active filter visible in the horizontally-scrollable header when
  // the hovered reaction is past the visible tabs. Re-runs whenever the active
  // filter changes (passed as a positional arg).
  scrollActiveFilterIntoView = modifier((element, [activeFilter]) => {
    if (!activeFilter) {
      return;
    }

    const button = element.querySelector(
      `[data-reaction-filter="${CSS.escape(activeFilter)}"]`
    );
    if (!button) {
      return;
    }

    const buttonRect = button.getBoundingClientRect();
    const containerRect = element.getBoundingClientRect();
    const overflowEnd = buttonRect.right - containerRect.right;
    const overflowStart = containerRect.left - buttonRect.left;

    if (overflowEnd > 0) {
      element.scrollLeft += overflowEnd + FILTER_SCROLL_PADDING;
    } else if (overflowStart > 0) {
      element.scrollLeft -= overflowStart + FILTER_SCROLL_PADDING;
    }
  });

  fetchUsers = async (page, pageSize) => {
    const filter = this.activeFilter;
    const offset = page * pageSize;
    const nextOffset = offset + pageSize;
    const entry = this.#tabCache.get(filter);

    if (entry) {
      const cached = entry.users.slice(offset, nextOffset);
      const fullPage = cached.length === pageSize;
      const lastPartialPage = !entry.canLoadMore && cached.length > 0;
      if (fullPage || lastPartialPage) {
        return {
          users: cached,
          canLoadMore: entry.users.length > nextOffset || entry.canLoadMore,
        };
      }
    }

    const result = await this.chatApi.messageReactionsUsers(
      this.channel.id,
      this.message.id,
      { page, limit: pageSize, emoji: filter }
    );
    const users = result.users ?? [];
    const canLoadMore = result.total_rows
      ? offset + users.length < result.total_rows
      : users.length >= pageSize;

    const existing = entry?.users ?? [];
    const merged = [...existing.slice(0, offset), ...users];
    this.#tabCache.set(filter, { users: merged, canLoadMore });

    if (filter === null && !canLoadMore) {
      for (const reaction of this.reactions) {
        this.#tabCache.set(reaction.emoji, {
          users: merged.filter((user) => user.reaction === reaction.emoji),
          canLoadMore: false,
        });
      }
    }

    return { users, canLoadMore };
  };
  #resetCallback = null;
  #tabCache = new Map();

  get message() {
    return this.args.data.message;
  }

  get channel() {
    return this.message.channel;
  }

  get reactions() {
    return this.message.reactions ?? [];
  }

  get showFilters() {
    return this.reactions.length > 1;
  }

  get totalReactions() {
    return this.reactions.reduce((sum, reaction) => sum + reaction.count, 0);
  }

  get titleText() {
    return i18n("chat.reactions.users_popup.title", {
      count: this.totalReactions,
    });
  }

  get activeFilterTotalUsers() {
    if (!this.activeFilter) {
      return this.totalReactions;
    }
    return this.reactions.find(
      (reaction) => reaction.emoji === this.activeFilter
    )?.count;
  }

  @action
  registerReset(resetFn) {
    this.#resetCallback = resetFn;
  }

  @action
  reload() {
    this.#resetCallback?.();
  }

  @action
  selectFilter(filterValue, event) {
    event.stopPropagation();
    event.preventDefault();
    this.activeFilter = filterValue;
  }

  <template>
    <UsersPopup
      @fetchUsers={{this.fetchUsers}}
      @titleText={{this.titleText}}
      @totalUsers={{this.activeFilterTotalUsers}}
      {{this.trackPointerForClose}}
    >
      <:header as |resetAndReload|>
        {{this.registerReset resetAndReload}}
        <span hidden {{didUpdate this.reload this.activeFilter}}></span>
        {{#if this.showFilters}}
          <div
            class="users-popup__header"
            {{this.scrollActiveFilterIntoView this.activeFilter}}
          >
            {{#each this.reactions as |reaction|}}
              <button
                type="button"
                class={{dConcatClass
                  "users-popup__filter"
                  (if (eq reaction.emoji this.activeFilter) "is-active")
                }}
                data-reaction-filter={{reaction.emoji}}
                {{on "click" (fn this.selectFilter reaction.emoji)}}
              >
                {{dEmoji reaction.emoji skipTitle=true}}
                <span>{{reaction.count}}</span>
              </button>
            {{/each}}
          </div>
        {{/if}}
      </:header>

      <:reaction as |user|>
        {{#if user.reaction}}
          {{dEmoji user.reaction skipTitle=true class="users-popup__reaction"}}
        {{/if}}
      </:reaction>
    </UsersPopup>
  </template>
}
