import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action, get } from "@ember/object";
import { bind } from "discourse/lib/decorators";
import { eq } from "discourse/truth-helpers";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DSmallUserList, {
  smallUserAttrs,
} from "discourse/ui-kit/d-small-user-list";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dCloseOnClickOutside from "discourse/ui-kit/modifiers/d-close-on-click-outside";
import { i18n } from "discourse-i18n";
import { whoVoted } from "../lib/post-voting-utilities";

export default class PostVotingWhoVotedList extends Component {
  @bind
  calcRemainingCount(voters) {
    return this.args.post.post_voting_vote_count - voters.length;
  }

  @bind
  splitUpAndDownLists(voters) {
    const upVoters = [];
    const downVoters = [];

    voters.forEach((voter) => {
      if (voter.direction === "up") {
        upVoters.push(voter);
      } else if (voter.direction === "down") {
        downVoters.push(voter);
      }
    });

    return { up: upVoters, down: downVoters };
  }

  @action
  async loadWhoVoted() {
    const result = await whoVoted({ post_id: this.args.post.id });

    return result.voters?.map((voter) => {
      const userAttrs = smallUserAttrs(voter);
      userAttrs.direction = voter.direction;
      return userAttrs;
    });
  }

  <template>
    <div
      class="post-voting-post-list"
      {{dCloseOnClickOutside
        @onClickOutside
        (hash
          targetSelector=".post-voting-post-list"
          secondaryTargetSelector=".post-voting-post-toggle-voters"
        )
      }}
    >
      <DAsyncContent @asyncData={{this.loadWhoVoted}}>
        <:loading>
          {{i18n "loading"}}
        </:loading>
        <:content as |voters|>
          {{#if whoVoted}}
            {{#let (this.splitUpAndDownLists voters) as |splitVoters|}}
              <PostVotingSmallUserList
                @list={{get splitVoters "up"}}
                @direction="up"
              />
              <PostVotingSmallUserList
                @list={{get splitVoters "down"}}
                @direction="down"
              />
            {{/let}}
            {{#let (this.calcRemainingCount voters) as |remainingCount|}}
              {{#if remainingCount}}
                <span>
                  {{i18n
                    "post_voting.topic.voters_count_diff"
                    count=remainingCount
                  }}
                </span>
              {{/if}}
            {{/let}}
          {{/if}}
        </:content>
      </DAsyncContent>
    </div>
  </template>
}

const PostVotingSmallUserList = <template>
  {{#if @list}}
    <div class="post-voting-post-list-voters-wrapper">
      <span class="post-voting-post-list-icon">
        {{dIcon (if (eq @direction "up") "angle-up" "angle-down")}}
      </span>
      <span class="post-voting-post-list-count">{{@list.length}}</span>
      <DSmallUserList class="post-voting-post-list-voters" @users={{@list}} />
    </div>
  {{/if}}
</template>;
