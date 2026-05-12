import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { gt } from "discourse/truth-helpers";
import DUserAvatar from "discourse/ui-kit/d-user-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const MAX_USERS_COUNT = 26;
const MIN_USERS_COUNT = 8;

export default class DiscourseReactionsStatePanelReaction extends Component {
  @action
  click(event) {
    if (event?.target?.classList?.contains("show-users")) {
      event.preventDefault();
      event.stopPropagation();

      this.args.showUsers(this.args.reaction.id);
    }
  }

  get firstLineUsers() {
    return this.args.users.slice(0, MIN_USERS_COUNT);
  }

  get otherUsers() {
    return this.args.users.slice(MIN_USERS_COUNT, MAX_USERS_COUNT);
  }

  get columnsCount() {
    return this.args.users.length > MIN_USERS_COUNT
      ? this.firstLineUsers.length + 1
      : this.firstLineUsers.length;
  }

  get groupAriaLabel() {
    return i18n("discourse_reactions.state_panel.reaction_group", {
      reaction: this.args.reaction.id,
      count: this.args.reaction.count,
    });
  }

  get moreLabel() {
    if (this.args.isDisplayed && this.args.reaction.count > MAX_USERS_COUNT) {
      return i18n("discourse_reactions.state_panel.more_users", {
        count: this.args.reaction.count - MAX_USERS_COUNT,
      });
    }
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <div
      class={{dConcatClass
        "discourse-reactions-state-panel-reaction"
        (if @isDisplayed "is-displayed")
      }}
      role="listitem"
      aria-label={{this.groupAriaLabel}}
      {{on "click" this.click}}
    >
      {{#if @users}}
        <div class="reaction-wrapper" aria-hidden="true">
          <div class="emoji-wrapper">
            {{dEmoji @reaction.id}}
          </div>
          <div class="count">
            {{@reaction.count}}
          </div>
        </div>

        <div class="users">
          <div class="list list-columns-{{this.columnsCount}}">
            {{#each this.firstLineUsers key="username" as |user|}}
              <span>
                <DUserAvatar
                  class="trigger-user-card"
                  @size="tiny"
                  @user={{user}}
                />
              </span>
            {{/each}}

            {{#if (gt @users.length MIN_USERS_COUNT)}}
              <button
                type="button"
                class="show-users"
                aria-label={{if
                  @isDisplayed
                  (i18n "discourse_reactions.state_panel.hide_users")
                  (i18n "discourse_reactions.state_panel.show_users")
                }}
              >
                {{dIcon (if @isDisplayed "chevron-up" "chevron-down")}}
              </button>
            {{/if}}

            {{#if @isDisplayed}}
              {{#each this.otherUsers key="username" as |user|}}
                <span>
                  <DUserAvatar
                    class="trigger-user-card"
                    @size="tiny"
                    @user={{user}}
                  />
                </span>
              {{/each}}
            {{/if}}
          </div>
          <span class="more">
            {{this.moreLabel}}
          </span>
        </div>
      {{/if}}
    </div>
  </template>
}
