import getURL from "discourse/lib/get-url";
import { applyValueTransformer } from "discourse/lib/transformer";
import {
  destroyUserStatusOnMentions,
  updateUserStatusOnMention,
} from "discourse/lib/update-user-status-on-mention";

export default function (element, context) {
  const { post, owner } = context;

  destroyUserStatusOnMentions();

  _extractMentions(element).forEach(({ mentions, user }) => {
    _trackMentionedUserStatus(user, post);
    _rerenderUserStatusOnMentions(mentions, user, owner);

    const classes = applyValueTransformer("mentions-class", [], {
      user,
    });

    mentions.forEach((mention) => {
      mention.classList.add(...classes);
    });
  });

  // cleanup code
  return () => {
    _stopTrackingMentionedUsersStatus(post);
    destroyUserStatusOnMentions();
  };
}

function _rerenderUserStatusOnMentions(mentions, user, owner) {
  mentions.forEach((mention) => {
    updateUserStatusOnMention(owner, mention, user.status);
  });
}

function _rerenderUsersStatusOnMentions() {
  _extractMentions().forEach(({ mentions, user }) => {
    _rerenderUserStatusOnMentions(mentions, user);
  });
}

function _extractMentions(element, post) {
  return (
    post?.mentioned_users?.map((user) => {
      const href = getURL(`/u/${user.username.toLowerCase()}`);
      const mentions = element.querySelectorAll(`a.mention[href="${href}"]`);

      return { user, mentions };
    }) || []
  );
}

function _trackMentionedUserStatus(user) {
  user.statusManager?.trackStatus?.();
  user.on?.("status-changed", this, _rerenderUsersStatusOnMentions);
}

function _stopTrackingMentionedUsersStatus(post) {
  post?.mentioned_users?.forEach((user) => {
    user.statusManager?.stopTrackingStatus?.();
    user.off?.("status-changed", this, _rerenderUsersStatusOnMentions);
  });
}
