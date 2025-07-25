import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "custom-post-message-callbacks",
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");

    if (!siteSettings.post_voting_enabled) {
      return;
    }

    withPluginApi("1.2.0", (api) => {
      api.registerCustomPostMessageCallback(
        "post_voting_post_comment_edited",
        (topicController, message) => {
          const postStream = topicController.get("model.postStream");
          const post = postStream.findLoadedPost(message.id);

          if (post) {
            const indexToUpdate = post.comments.findIndex(
              (comment) =>
                comment.id === message.comment_id &&
                comment.raw !== message.comment_raw
            );

            if (indexToUpdate !== -1) {
              const updatedComment = {
                ...post.comments[indexToUpdate],
                raw: message.comment_raw,
                cooked: message.comment_cooked,
              };
              post.comments.replace(indexToUpdate, 1, [updatedComment]);

              topicController.appEvents.trigger("post-stream:refresh", {
                id: post.id,
              });
            }
          }
        }
      );

      api.registerCustomPostMessageCallback(
        "post_voting_post_comment_trashed",
        (topicController, message) => {
          const postStream = topicController.get("model.postStream");
          const post = postStream.findLoadedPost(message.id);

          if (post) {
            const indexToDelete = post.comments.findIndex(
              (comment) => comment.id === message.comment_id && !comment.deleted
            );

            if (indexToDelete !== -1) {
              const comment = {
                ...post.comments[indexToDelete],
                deleted: true,
              };
              post.comments.replace(indexToDelete, 1, [comment]);
            }

            post.set("comments_count", message.comments_count);

            topicController.appEvents.trigger("post-stream:refresh", {
              id: post.id,
            });
          }
        }
      );

      api.registerCustomPostMessageCallback(
        "post_voting_post_commented",
        (topicController, message) => {
          const postStream = topicController.get("model.postStream");
          const post = postStream.findLoadedPost(message.id);

          if (
            post &&
            !post.comments.some((comment) => comment.id === message.comment.id)
          ) {
            post.setProperties({
              comments_count: message.comments_count,
            });

            if (
              post.comments_count - post.comments.length <= 1 &&
              topicController.currentUser.id !== message.comment.user_id
            ) {
              post.comments.pushObject(message.comment);
            }

            topicController.appEvents.trigger("post-stream:refresh", {
              id: post.id,
            });
          }
        }
      );

      api.registerCustomPostMessageCallback(
        "post_voting_post_voted",
        (topicController, message) => {
          const postStream = topicController.get("model.postStream");
          const post = postStream.findLoadedPost(message.id);

          if (post) {
            const props = {
              post_voting_vote_count: message.post_voting_vote_count,
              post_voting_has_votes: message.post_voting_has_votes,
            };

            if (
              topicController.currentUser.id ===
              message.post_voting_user_voted_id
            ) {
              props.post_voting_user_voted_direction =
                message.post_voting_user_voted_direction;
            }

            post.setProperties(props);

            topicController.appEvents.trigger("post-stream:refresh", {
              id: post.id,
            });
          }
        }
      );
    });
  },
};
