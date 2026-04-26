import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import PostUsersMenu from "discourse/components/post/menu/post-users-menu";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import emoji from "discourse/helpers/emoji";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import CustomReaction from "../models/discourse-reactions-custom-reaction";

export default class DiscourseReactionsUsersMenu extends Component {
  @tracked activeFilter = null;

  fetchUsers = async (page, pageSize) => {
    const result = await CustomReaction.fetchReactionsUsersList(
      this.post.id,
      page,
      pageSize,
      this.activeFilter
    );

    const loadedSoFar = page * pageSize + (result.users?.length ?? 0);
    const canLoadMore = result.total_rows
      ? loadedSoFar < result.total_rows
      : (result.users?.length ?? 0) >= pageSize;

    return { users: result.users ?? [], canLoadMore };
  };
  #resetCallback = null;

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
  registerReset(resetFn) {
    this.#resetCallback = resetFn;
  }

  @action
  selectFilter(filterId, event) {
    event.stopPropagation();
    event.preventDefault();
    if (this.activeFilter === filterId) {
      return;
    }

    this.activeFilter = filterId;
    this.#resetCallback?.();
  }

  <template>
    <PostUsersMenu
      @fetchUsers={{this.fetchUsers}}
      @titleText={{this.titleText}}
    >
      <:header as |resetAndReload|>
        {{this.registerReset resetAndReload}}
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
      </:header>

      <:reaction as |user|>
        {{#if user.reaction}}
          {{emoji
            user.reaction
            skipTitle=true
            class="post-users-popup__reaction"
          }}
        {{else}}
          {{icon "d-liked" class="post-users-popup__reaction"}}
        {{/if}}
      </:reaction>
    </PostUsersMenu>
  </template>
}
