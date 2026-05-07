import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action, get } from "@ember/object";
import AsyncContent from "discourse/components/async-content";
import SmallUserList, {
  smallUserAttrs,
} from "discourse/components/small-user-list";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { bind } from "discourse/lib/decorators";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import { whoVoted } from "../lib/post-voting-utilities";

export default class PostVotingWhoVotedList extends Component {
  @tracked totalVotersCount = 0;

  @bind
  calcRemainingCount(voters) {
    return Math.max(0, this.totalVotersCount - voters.length);
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
    this.totalVotersCount = result.total_voters_count ?? 0;

    return result.voters?.map((voter) => {
      const userAttrs = smallUserAttrs(voter);
      userAttrs.direction = voter.direction;
      return userAttrs;
    });
  }

  <template>
    <AsyncContent @asyncData={{this.loadWhoVoted}}>
      <:loading>
        {{i18n "loading"}}
      </:loading>
      <:content as |voters|>
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
      </:content>
    </AsyncContent>
  </template>
}

const PostVotingSmallUserList = <template>
  {{#if @list}}
    <div class="post-voting-popup-content__wrapper">
      <span
        class={{concatClass
          "post-voting-popup-content__icon"
          (if (eq @direction "up") "--upvote" "--downvote")
        }}
        aria-label={{i18n
          (if (eq @direction "up") "vote.upvotes" "vote.downvotes")
        }}
      >
        {{icon "vote-up-filled"}}
      </span>
      <span class="post-voting-popup-content__count">{{@list.length}}</span>
      <SmallUserList
        class="post-voting-popup-content__voters"
        @users={{@list}}
      />
    </div>
  {{/if}}
</template>;
