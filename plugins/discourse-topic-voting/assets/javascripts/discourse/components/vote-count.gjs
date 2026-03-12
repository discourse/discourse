import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import { eq } from "discourse/truth-helpers";
import AsyncContent from "discourse/ui-kit/d-async-content";
import SmallUserList from "discourse/ui-kit/d-small-user-list";
import concatClass from "discourse/ui-kit/helpers/d-concat-class";
import closeOnClickOutside from "discourse/ui-kit/modifiers/d-close-on-click-outside";

export default class VoteBox extends Component {
  @service siteSettings;
  @service currentUser;

  @tracked showWhoVoted = false;

  @bind
  async loadWhoVoted() {
    return ajax("/voting/who", {
      type: "GET",
      data: {
        topic_id: this.args.topic.id,
      },
    }).then((users) =>
      users.map((user) => {
        return {
          template: user.avatar_template,
          username: user.username,
          post_url: user.post_url,
          url: getURL("/u/") + user.username.toLowerCase(),
        };
      })
    );
  }

  @action
  click(event) {
    event.preventDefault();
    event.stopPropagation();

    if (!this.currentUser) {
      return this.args.showLogin();
    }

    if (this.showWhoVoted) {
      this.showWhoVoted = false;
    } else if (this.siteSettings.topic_voting_show_who_voted) {
      this.showWhoVoted = true;
    }
  }

  @action
  clickOutside() {
    this.showWhoVoted = false;
  }

  <template>
    <div
      class={{concatClass
        "vote-count-wrapper"
        (if (eq @topic.vote_count 0) "no-votes")
      }}
      {{on "click" this.click}}
      role="button"
    >
      <div class="vote-count">
        {{@topic.vote_count}}
      </div>
    </div>

    {{#if this.showWhoVoted}}
      <div
        class="who-voted popup-menu voting-popup-menu"
        {{closeOnClickOutside
          this.clickOutside
          (hash secondaryTargetSelector=".vote-count-wrapper")
        }}
      >
        <AsyncContent @asyncData={{this.loadWhoVoted}}>
          <:content as |voters|>
            <SmallUserList @users={{voters}} class="regular-votes" />
          </:content>
        </AsyncContent>
      </div>
    {{/if}}
  </template>
}
