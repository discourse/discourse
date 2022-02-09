import { Promise } from "rsvp";
let model, currentTopicId;

let lastTopicId, lastHighestRead;

export function setTopicList(incomingModel) {
  model = incomingModel;

  model?.topics?.forEach((topic) => {
    let highestRead = getHighestReadCache(topic.id);
    if (highestRead && highestRead >= topic.last_read_post_number) {
      let count = Math.max(topic.highest_post_number - highestRead, 0);
      topic.setProperties({
        unread_posts: count,
        new_posts: count,
      });
      resetHighestReadCache();
    }
  });
  currentTopicId = null;
}

export function nextTopicUrl() {
  return urlAt(1);
}

export function previousTopicUrl() {
  return urlAt(-1);
}

export function setHighestReadCache(topicId, postNumber) {
  lastTopicId = topicId;
  lastHighestRead = postNumber;
}

export function getHighestReadCache(topicId) {
  if (topicId === lastTopicId) {
    return lastHighestRead;
  }
}

export function resetHighestReadCache() {
  lastTopicId = undefined;
  lastHighestRead = undefined;
}

function urlAt(delta) {
  if (!model || !model.topics) {
    return Promise.resolve(null);
  }

  let index = currentIndex();
  if (index === -1) {
    index = 0;
  } else {
    index += delta;
  }

  const topic = model.topics[index];

  if (!topic && index > 0 && model.more_topics_url && model.loadMore) {
    return model.loadMore().then(() => urlAt(delta));
  }

  if (topic) {
    currentTopicId = topic.id;
    return Promise.resolve(topic.lastUnreadUrl);
  }

  return Promise.resolve(null);
}

export function setTopicId(topicId) {
  currentTopicId = topicId;
}

function currentIndex() {
  if (currentTopicId && model && model.topics) {
    const idx = model.topics.findIndex((t) => t.id === currentTopicId);
    if (idx > -1) {
      return idx;
    }
  }

  return -1;
}
