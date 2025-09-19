import Component from "@glimmer/component";
import routeAction from "discourse/helpers/route-action";
import { withPluginApi } from "discourse/lib/plugin-api";
import PostVotingAnswerButton from "../components/post-voting-answer-button";
import PostVotingAnswerHeader, {
  ORDER_BY_ACTIVITY_FILTER,
} from "../components/post-voting-answer-header";
import PostVotingComments from "../components/post-voting-comments";
import PostVotingVoteControls from "../components/post-voting-vote-controls";

function initPlugin(api, container) {
  customizePost(api);
  customizePostMenu(api, container);

  function customLastUnreadUrl(context) {
    if (context.is_post_voting && context.last_read_post_number) {
      if (context.highest_post_number <= context.last_read_post_number) {
        // link to OP if no unread
        return context.urlForPostNumber(1);
      } else if (
        context.last_read_post_number ===
        context.highest_post_number - 1
      ) {
        return context.urlForPostNumber(context.last_read_post_number + 1);
      } else {
        // sort by activity if user has 2+ unread posts
        return `${context.urlForPostNumber(
          context.last_read_post_number + 1
        )}?filter=activity`;
      }
    }
  }

  api.registerCustomLastUnreadUrlCallback(customLastUnreadUrl);
}

function customizePost(api) {
  api.addTrackedPostProperties(
    "comments",
    "comments_count",
    "post_voting_user_voted_direction",
    "post_voting_has_votes"
  );

  api.modifyClass(
    "model:post-stream",
    (Superclass) =>
      class extends Superclass {
        orderStreamByActivity() {
          this.cancelFilter();
          this.set("filter", ORDER_BY_ACTIVITY_FILTER);
          return this.refreshAndJumpToSecondVisible();
        }

        orderStreamByVotes() {
          this.cancelFilter();
          return this.refreshAndJumpToSecondVisible();
        }
      }
  );

  api.renderAfterWrapperOutlet(
    "post-avatar",
    class extends Component {
      static shouldRender(args) {
        return args.post.topic?.is_post_voting;
      }

      <template>
        <PostVotingVoteControls
          @post={{@outletArgs.post}}
          @showLogin={{routeAction "showLogin"}}
        />
      </template>
    }
  );
  api.renderBeforeWrapperOutlet("post-article", PostVotingAnswerHeader);
}

function customizePostMenu(api, container) {
  const siteSettings = container.lookup("service:site-settings");

  api.registerValueTransformer(
    "post-menu-buttons",
    ({ value: dag, context: { post, buttonKeys } }) => {
      if (post.post_voting_has_votes !== undefined) {
        dag.add("post-voting-answer", PostVotingAnswerButton, {
          after: [buttonKeys.SHOW_MORE, buttonKeys.REPLY],
        });

        dag.delete(buttonKeys.REPLY);

        if (
          post.post_number !== 1 &&
          !siteSettings.post_voting_enable_likes_on_answers
        ) {
          dag.delete(buttonKeys.LIKE);
        }
      }
    }
  );

  api.renderInOutlet(
    "post-menu__after",
    class extends Component {
      static shouldRender(args) {
        if (!siteSettings.post_voting_comment_enabled) {
          return false;
        }

        return (
          args.post.post_voting_has_votes !== undefined &&
          !args.post.reply_to_post_number &&
          !(args.state.filteredRepliesView && args.state.repliesShown)
        );
      }

      <template>
        <PostVotingComments
          @post={{@outletArgs.post}}
          @canCreatePost={{@outletArgs.state.canCreatePost}}
        />
      </template>
    }
  );
}

export default {
  name: "post-voting-edits",
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");

    if (!siteSettings.post_voting_enabled) {
      return;
    }

    withPluginApi((api) => {
      initPlugin(api, container);
    });
  },
};
