export function getTopicStatusBadge(topic) {
  if (topic.is_hot) {
    return {
      icon: "fire",
      text: "topic_statuses.hot.title",
      className: "--hot",
    };
  }

  if (topic.pinned || topic.pinned_globally) {
    return {
      icon: "thumbtack",
      text: "topic_statuses.pinned.title",
      className: "--pinned",
    };
  }

  return null;
}
