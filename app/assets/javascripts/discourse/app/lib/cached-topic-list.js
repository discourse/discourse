export function setCachedTopicList(session, topicList) {
  session.set("topicList", topicList);
}

export function getCachedTopicList(session) {
  session.get("topicList");
}

export function resetCachedTopicList(session) {
  session.setProperties({
    topicList: null,
  });
}

export function findOrResetCachedTopicList(session, filter) {
  const lastTopicList = session.get("topicList");

  if (lastTopicList && lastTopicList.filter === filter) {
    return lastTopicList;
  } else {
    resetCachedTopicList(session);
    return false;
  }
}
