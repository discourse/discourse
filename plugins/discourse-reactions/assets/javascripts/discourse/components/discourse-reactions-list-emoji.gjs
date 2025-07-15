import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { debounce, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { createPopper } from "@popperjs/core";
import emoji from "discourse/helpers/emoji";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

const DISPLAY_MAX_USERS = 19;
let _popperReactionUserPanel;

export default class DiscourseReactionsListEmoji extends Component {
  @service siteSettings;

  @tracked loadingReactions = false;

  get elementId() {
    return `discourse-reactions-list-emoji-${this.args.post.id}-${this.args.reaction.id}`;
  }

  @action
  pointerOver(event) {
    if (event.pointerType !== "mouse") {
      return;
    }

    this._setupPopper(".user-list");

    if (!this.args.users?.length && !this.loadingReactions) {
      debounce(this, this._loadReactionUsers, 3000, true);
    }
  }

  _setupPopper(selector) {
    schedule("afterRender", () => {
      const elementId = CSS.escape(this.elementId);
      const trigger = document.querySelector(`#${elementId}`);
      const popperElement = document.querySelector(`#${elementId} ${selector}`);

      if (popperElement) {
        _popperReactionUserPanel && _popperReactionUserPanel.destroy();
        _popperReactionUserPanel = createPopper(trigger, popperElement, {
          placement: "bottom",
          modifiers: [
            {
              name: "offset",
              options: {
                offset: [0, -5],
              },
            },
            {
              name: "preventOverflow",
              options: {
                padding: 5,
              },
            },
          ],
        });
      }
    });
  }

  _loadReactionUsers() {
    this.loadingReactions = true;
    this.args.getUsers(this.args.reaction.id).finally(() => {
      this.loadingReactions = false;
    });
  }

  get truncatedUsers() {
    return this.args.users?.slice(0, DISPLAY_MAX_USERS);
  }

  @bind
  displayNameForUser(user) {
    if (
      !this.siteSettings.prioritize_username_in_ux &&
      this.siteSettings.prioritize_full_name_in_ux
    ) {
      return user.name || user.username;
    } else if (this.siteSettings.prioritize_username_in_ux) {
      return user.username;
    } else if (!user.name) {
      return user.username;
    } else {
      return user.name;
    }
  }

  get hiddenUserCount() {
    return this.args.users?.length - this.truncatedUsers?.length;
  }

  <template>
    <div
      class="discourse-reactions-list-emoji"
      id={{this.elementId}}
      {{on "pointerover" this.pointerOver}}
    >
      {{#if @reaction.count}}
        {{emoji
          @reaction.id
          skipTitle=true
          class=(if
            this.siteSettings.discourse_reactions_desaturated_reaction_panel
            "desaturated"
            ""
          )
        }}

        <div class="user-list">
          <div class="container">
            <span class="heading">{{@reaction.id}}</span>
            {{#each this.truncatedUsers as |user|}}
              <span class="username">{{this.displayNameForUser user}}</span>
            {{else}}
              <div class="center"><div class="spinner small"></div></div>
            {{/each}}
            {{#if this.hiddenUserCount}}
              <span class="other-users">
                {{i18n
                  "discourse_reactions.state_panel.more_users"
                  count=this.hiddenUserCount
                }}
              </span>
            {{/if}}
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
