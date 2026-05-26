import {
  CREATE_SHARED_DRAFT,
  CREATE_TOPIC,
  PRIVATE_MESSAGE,
  REPLY,
} from "discourse/models/composer";
import { i18n } from "discourse-i18n";

export function buildComposerActionItems({
  action,
  topic,
  post,
  replyOptions,
  snapshots = {},
  currentUser,
  site,
  isEditing,
  postDisplayName,
}) {
  const items = [];
  const snapshotTopic = snapshots.topic;
  const snapshotPost = snapshots.post;
  const displayName =
    typeof postDisplayName === "function"
      ? postDisplayName
      : () => postDisplayName;

  if (
    action === REPLY &&
    action !== CREATE_TOPIC &&
    action !== CREATE_SHARED_DRAFT &&
    topic &&
    !topic.isPrivateMessage &&
    !isEditing &&
    currentUser?.can_create_topic &&
    topic.id
  ) {
    items.push({
      name: i18n("composer.composer_actions.reply_as_new_topic.label"),
      description: i18n("composer.composer_actions.reply_as_new_topic.desc"),
      icon: "far-pen-to-square",
      id: "reply_as_new_topic",
    });
  }

  if (
    action === REPLY &&
    !isEditing &&
    topic?.isPrivateMessage &&
    topic.details &&
    (topic.details.allowed_users?.length > 1 ||
      topic.details.allowed_groups?.length > 0)
  ) {
    items.push({
      name: i18n("composer.composer_actions.reply_as_new_group_message.label"),
      description: i18n(
        "composer.composer_actions.reply_as_new_group_message.desc"
      ),
      icon: "plus",
      id: "reply_as_new_group_message",
    });
  }

  const canRestoreReplyToPost =
    action === REPLY &&
    !post &&
    snapshotPost &&
    snapshotTopic &&
    topic?.id === snapshotTopic.id;

  if (
    !isEditing &&
    ((action !== REPLY && post) ||
      (action === REPLY &&
        post &&
        !(replyOptions?.userAvatar && replyOptions?.userLink)) ||
      canRestoreReplyToPost)
  ) {
    const postForLabel = post || snapshotPost;

    items.push({
      name: i18n("composer.composer_actions.reply_to_post.label", {
        postUsername: displayName(postForLabel),
      }),
      description: i18n("composer.composer_actions.reply_to_post.desc"),
      icon: "share",
      id: "reply_to_post",
    });
  }

  if (
    !isEditing &&
    action !== CREATE_TOPIC &&
    action !== PRIVATE_MESSAGE &&
    ((action !== REPLY && topic) ||
      (action === REPLY &&
        topic &&
        replyOptions?.userAvatar &&
        replyOptions?.userLink &&
        replyOptions?.topicLink))
  ) {
    items.push({
      name: i18n("composer.composer_actions.reply_to_topic.label"),
      description: i18n("composer.composer_actions.reply_to_topic.desc"),
      icon: "share",
      id: "reply_to_topic",
    });
  }

  const inCreateTopicLike =
    action === CREATE_TOPIC || action === CREATE_SHARED_DRAFT;

  if (inCreateTopicLike && !isEditing && snapshotPost && snapshotTopic) {
    items.push({
      name: i18n("composer.composer_actions.reply_to_post.label", {
        postUsername: displayName(snapshotPost),
      }),
      description: i18n("composer.composer_actions.reply_to_post.desc"),
      icon: "share",
      id: "reply_to_post",
    });
  }

  if (inCreateTopicLike && !isEditing && snapshotTopic) {
    items.push({
      name: i18n("composer.composer_actions.reply_to_topic.label"),
      description: i18n("composer.composer_actions.reply_to_topic.desc"),
      icon: "share",
      id: "reply_to_topic",
    });
  }

  if (action === CREATE_TOPIC && site?.shared_drafts_category_id) {
    items.push({
      name: i18n("composer.composer_actions.shared_draft.label"),
      description: i18n("composer.composer_actions.shared_draft.desc"),
      icon: "far-clipboard",
      id: "shared_draft",
    });
  }

  if (
    action === CREATE_SHARED_DRAFT &&
    currentUser?.can_create_topic &&
    !isEditing
  ) {
    items.push({
      name: i18n("composer.composer_actions.create_topic.label"),
      description: i18n("composer.composer_actions.create_topic.desc"),
      icon: "far-pen-to-square",
      id: "create_topic",
    });
  }

  if (
    currentUser?.can_send_private_messages &&
    inCreateTopicLike &&
    !isEditing
  ) {
    items.push({
      name: i18n("composer.composer_actions.create_personal_message.label"),
      description: i18n(
        "composer.composer_actions.create_personal_message.desc"
      ),
      icon: "envelope",
      id: "create_private_message",
    });
  }

  if (action === PRIVATE_MESSAGE && !isEditing && snapshotTopic) {
    items.push({
      name: i18n("composer.composer_actions.reply_to_topic.label"),
      description: i18n("composer.composer_actions.reply_to_topic.desc"),
      icon: "share",
      id: "reply_to_topic",
    });
  }

  if (
    action === PRIVATE_MESSAGE &&
    currentUser?.can_create_topic &&
    !isEditing
  ) {
    items.push({
      name: i18n("composer.composer_actions.create_topic.label"),
      description: i18n("composer.composer_actions.create_topic.desc"),
      icon: "far-pen-to-square",
      id: "create_topic",
    });
  }

  return items;
}
