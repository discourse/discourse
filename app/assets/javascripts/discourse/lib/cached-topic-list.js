export function findOrResetCachedTopicList(session, filter) {
  const lastTopicList = session.get("topicList");
  if (lastTopicList && lastTopicList.filter === filter) {
    return lastTopicList;
  } else {
    session.setProperties({
      topicList: null,
      topicListScrollPosition: null
    });
    return false;
  }
}
