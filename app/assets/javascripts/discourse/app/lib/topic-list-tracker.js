import { Promise } from "rsvp";
let model, currentTopicId;

let highestReadCache = {};

export function setTopicList(incomingModel) {
  model = incomingModel;

  model?.topics?.forEach((topic) => {
    let highestReadFromCache = highestReadCache[topic.id];
    if (
      highestReadCache &&
      highestReadFromCache >= topic.last_read_post_number
    ) {
      let count = Math.max(topic.highest_post_number - highestReadFromCache, 0);
      topic.setProperties({
        unread_posts: count,
        new_posts: count,
      });
    }
    deleteHighestReadCache(topic.id);
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
  highestReadCache[topicId] = postNumber;
}

export function getHighestReadCache(topicId) {
  return highestReadCache[topicId];
}

export function deleteHighestReadCache(topicId) {
  delete highestReadCache[topicId];
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
