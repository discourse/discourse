export function findOrResetCachedTopicList(session, filter, params) {
  const lastTopicList = session.get("topicList");

  if (
    lastTopicList &&
    lastTopicList.filter === filter &&
    lastTopicList.params.tag === params?.tag
  ) {
    return lastTopicList;
  } else {
    session.setProperties({
      topicList: null,
      topicListScrollPosition: null,
    });
    return false;
  }
}
