import getURL from "discourse/lib/get-url";
import { applyValueTransformer } from "discourse/lib/transformer";
import {
  destroyUserStatusOnMentions,
  updateUserStatusOnMention,
} from "discourse/lib/update-user-status-on-mention";

export default function (element, context) {
  const {
    data: { post },
    state,
    owner,
  } = context;

  state.extractedMentions = _extractMentions(element, post);

  const userStatusService = owner.lookup("service:user-status");

  if (userStatusService.isEnabled) {
    destroyUserStatusOnMentions();
  }

  const _updateUserStatus = (updatedUser) => {
    state.extractedMentions
      .filter(({ user }) => updatedUser.id === user?.id)
      .forEach(({ mentions, user }) => {
        _renderUserStatusOnMentions(mentions, user, owner);
      });
  };

  state.extractedMentions.forEach(({ mentions, user }) => {
    if (userStatusService.isEnabled) {
      user.statusManager?.trackStatus?.();
      user.on?.("status-changed", element, _updateUserStatus);

      _renderUserStatusOnMentions(mentions, user, owner);
    }

    const classes = applyValueTransformer("mentions-class", [], {
      user,
    });

    mentions.forEach((mention) => {
      mention.classList.add(...classes);
    });
  });

  // cleanup code
  return () => {
    state.extractedMentions = [];

    if (userStatusService.isEnabled) {
      post?.mentioned_users?.forEach((user) => {
        user.statusManager?.stopTrackingStatus?.();
        user.off?.("status-changed", element, _updateUserStatus);
      });
    }

    destroyUserStatusOnMentions();
  };
}

function _renderUserStatusOnMentions(mentions, user, owner) {
  mentions.forEach((mention) => {
    updateUserStatusOnMention(owner, mention, user.status);
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
