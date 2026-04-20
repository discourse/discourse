import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import UserAvatar from "discourse/components/user-avatar";
import UserLink from "discourse/components/user-link";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import emoji from "discourse/helpers/emoji";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import CustomReaction from "../models/discourse-reactions-custom-reaction";

const PAGE_SIZE = 30;

export default class DiscourseReactionsUsersMenu extends Component {
  @service siteSettings;
  @service site;

  @tracked users = [];
  @tracked loading = false;
  @tracked canLoadMore = true;
  @tracked activeFilter = null;

  displayName = (user) => {
    if (user.name && !this.siteSettings.prioritize_username_in_ux) {
      return user.name;
    }
    return user.username;
  };
  #page = 0;

  get post() {
    return this.args.data.post;
  }

  get reactions() {
    return this.post.reactions || [];
  }

  get showFilters() {
    return this.reactions.length > 1;
  }

  get titleText() {
    return i18n("discourse_reactions.users_popup.title", {
      count: this.post.reaction_users_count,
    });
  }

  @action
  async loadInitial() {
    await this.#loadMore();
  }

  @action
  onScroll(event) {
    const el = event.target;
    if (el.scrollTop + el.clientHeight >= el.scrollHeight - 50) {
      this.#loadMore();
    }
  }

  @action
  async selectFilter(filterId, event) {
    event.stopPropagation();
    event.preventDefault();
    if (this.activeFilter === filterId) {
      return;
    }

    this.activeFilter = filterId;
    this.users = [];
    this.#page = 0;
    this.canLoadMore = true;
    await this.#loadMore();
  }

  async #loadMore() {
    if (this.loading || !this.canLoadMore) {
      return;
    }

    this.loading = true;

    try {
      const result = await CustomReaction.fetchReactionsUsersList(
        this.post.id,
        this.#page,
        PAGE_SIZE,
        this.activeFilter
      );

      const loadedSoFar = this.#page * PAGE_SIZE + (result.users?.length ?? 0);
      this.users = [...this.users, ...(result.users ?? [])];
      this.#page++;
      this.canLoadMore = result.total_rows
        ? loadedSoFar < result.total_rows
        : (result.users?.length ?? 0) >= PAGE_SIZE;
    } finally {
      this.loading = false;
    }
  }

  <template>
    <div class="post-users-popup">
      {{#if this.site.mobileView}}
        <div class="post-users-popup__title">{{this.titleText}}</div>
      {{/if}}

      {{#if this.showFilters}}
        <div class="post-users-popup__header">
          <button
            type="button"
            class={{concatClass
              "post-users-popup__filter"
              (unless this.activeFilter "is-active")
            }}
            data-reaction-filter="all"
            {{on "click" (fn this.selectFilter null)}}
          >
            {{i18n "discourse_reactions.users_popup.all"}}
          </button>
          {{#each this.reactions as |reaction|}}
            <button
              type="button"
              class={{concatClass
                "post-users-popup__filter"
                (if (eq reaction.id this.activeFilter) "is-active")
              }}
              data-reaction-filter={{reaction.id}}
              {{on "click" (fn this.selectFilter reaction.id)}}
            >
              {{emoji reaction.id skipTitle=true}}
              <span>{{reaction.count}}</span>
            </button>
          {{/each}}
        </div>
      {{/if}}

      <div
        class="post-users-popup__body"
        {{on "scroll" this.onScroll}}
        {{didInsert this.loadInitial}}
      >
        {{#each this.users as |user|}}
          <div class="post-users-popup__item">
            <UserLink
              @username={{user.username}}
              class="post-users-popup__avatar-link"
            >
              <UserAvatar @user={{user}} @size="small" />
            </UserLink>
            <div class="post-users-popup__user-info">
              <UserLink
                @username={{user.username}}
                class="post-users-popup__name"
              >
                {{this.displayName user}}
              </UserLink>
              {{#unless this.siteSettings.prioritize_username_in_ux}}
                <UserLink
                  @username={{user.username}}
                  class="post-users-popup__username"
                >
                  @{{user.username}}
                </UserLink>
              {{/unless}}
            </div>
            {{#if user.reaction}}
              {{emoji
                user.reaction
                skipTitle=true
                class="post-users-popup__reaction"
              }}
            {{else}}
              {{icon "d-liked" class="post-users-popup__reaction"}}
            {{/if}}
          </div>
        {{/each}}
        {{#if this.loading}}
          <div class="post-users-popup__loading">
            <div class="spinner small"></div>
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
