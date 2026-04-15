import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import PostUsersPopup from "discourse/components/post-users-popup";
import concatClass from "discourse/helpers/concat-class";
import emoji from "discourse/helpers/emoji";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import CustomReaction from "../models/discourse-reactions-custom-reaction";

export default class DiscourseReactionsUsersPopup extends Component {
  @tracked activeFilter = null;

  fetchUsers = async (page, pageSize) => {
    const result = await CustomReaction.fetchReactionsUsersList(
      this.post.id,
      page,
      pageSize,
      this.activeFilter
    );

    const loadedSoFar = page * pageSize + result.users.length;
    return {
      users: result.users,
      canLoadMore: result.total_rows
        ? loadedSoFar < result.total_rows
        : result.users.length >= pageSize,
    };
  };
  #resetCallback = null;

  get post() {
    return this.args.post;
  }

  get reactions() {
    return this.post.reactions || [];
  }

  get showFilters() {
    return this.reactions.length > 1;
  }

  get referenceElement() {
    return this.args.referenceElement;
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

  @action
  registerReset(resetFn) {
    this.#resetCallback = resetFn;
  }

  <template>
    <PostUsersPopup
      @referenceElement={{this.referenceElement}}
      @fetchUsers={{this.fetchUsers}}
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
                {{on "click" (fn this.selectFilter reaction.id)}}
              >
                {{emoji reaction.id skipTitle=true}}
                <span>{{reaction.count}}</span>
              </button>
            {{/each}}
          </div>
        {{/if}}
      </:header>
    </PostUsersPopup>
  </template>
}
