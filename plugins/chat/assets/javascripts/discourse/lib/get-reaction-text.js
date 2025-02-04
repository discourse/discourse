import { i18n } from "discourse-i18n";

export const MAX_DISPLAYED_USERNAMES = 15;

function filterUsernames(users, currentUser) {
  return users
    .filter((user) => user.id !== currentUser?.id)
    .slice(0, MAX_DISPLAYED_USERNAMES)
    .mapBy("username");
}

function reactionIncludingCurrentUser(reaction, currentUser) {
  if (reaction.count === 1) {
    return i18n("chat.reactions.only_you", {
      emoji: reaction.emoji,
    });
  }

  const usernames = filterUsernames(reaction.users, currentUser);

  if (reaction.count === 2) {
    return i18n("chat.reactions.you_and_single_user", {
      emoji: reaction.emoji,
      username: usernames.pop(),
    });
  }

  // - 1 for "you"
  const unnamedUserCount = reaction.count - usernames.length - 1;

  if (unnamedUserCount > 0) {
    return i18n("chat.reactions.you_multiple_users_and_more", {
      emoji: reaction.emoji,
      commaSeparatedUsernames: joinUsernames(usernames),
      count: unnamedUserCount,
    });
  }

  return i18n("chat.reactions.you_and_multiple_users", {
    emoji: reaction.emoji,
    username: usernames.pop(),
    commaSeparatedUsernames: joinUsernames(usernames),
  });
}

function reactionText(reaction, currentUser) {
  const usernames = filterUsernames(reaction.users, currentUser);

  if (reaction.count === 1) {
    return i18n("chat.reactions.single_user", {
      emoji: reaction.emoji,
      username: usernames.pop(),
    });
  }

  const unnamedUserCount = reaction.count - usernames.length;

  if (unnamedUserCount > 0) {
    return i18n("chat.reactions.multiple_users_and_more", {
      emoji: reaction.emoji,
      commaSeparatedUsernames: joinUsernames(usernames),
      count: unnamedUserCount,
    });
  }

  return i18n("chat.reactions.multiple_users", {
    emoji: reaction.emoji,
    username: usernames.pop(),
    commaSeparatedUsernames: joinUsernames(usernames),
  });
}

function joinUsernames(usernames) {
  return usernames.join(i18n("word_connector.comma"));
}

export function getReactionText(reaction, currentUser) {
  if (reaction.count === 0) {
    return;
  }

  if (reaction.reacted) {
    return reactionIncludingCurrentUser(reaction, currentUser);
  } else {
    return reactionText(reaction, currentUser);
  }
}
