import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import UsersPopup from "discourse/components/user/users-popup";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import { i18n } from "discourse-i18n";

export default class ChatMessageReactionsUsers extends Component {
  @service chatApi;

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

  // The active emoji filter is owned by the message so a single open menu can
  // switch filters as the user moves between reactions. `null` means "all".
  get activeFilter() {
    return this.args.data.getActiveEmoji?.() ?? null;
  }

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
    this.args.data.selectEmoji?.(filterValue);
  }

  <template>
    <UsersPopup
      @fetchUsers={{this.fetchUsers}}
      @titleText={{this.titleText}}
      @totalUsers={{this.activeFilterTotalUsers}}
    >
      <:header as |resetAndReload|>
        {{this.registerReset resetAndReload}}
        <span hidden {{didUpdate this.reload this.activeFilter}}></span>
        {{#if this.showFilters}}
          <div class="users-popup__header">
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
