import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import AiSearchReferences, {
  citedTopicsFromCooked,
  citedTopicsFromRaw,
} from "../../lib/ai-search-references.js";
import AiSearchReferencesPanel from "./ai-search-references-panel.gjs";

/**
 * The topics a conversation continued from a combined search has cited, the
 * latest citations first. It stands in for the timeline.
 */
export default class AiSearchConversationReferences extends Component {
  @service currentUser;
  @service messageBus;

  @tracked references = [];

  #ranker = new AiSearchReferences();
  #lookedUp = new Set();
  #topics = new Map();
  #currentTurn = 0;
  #loaded = false;
  #rankedPostNumber = 0;

  constructor() {
    super(...arguments);
    this.messageBus.subscribe(this.#channel, this.onStream);
    this.#load();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe(this.#channel, this.onStream);
  }

  get #channel() {
    return `discourse-ai/ai-bot/topic/${this.args.topic.id}`;
  }

  // a reply that finishes while the conversation loads is ranked with the rest
  @bind
  onStream(data) {
    if (!this.#loaded || !data?.done || !data.post_number) {
      return;
    }
    if (data.post_number <= this.#rankedPostNumber) {
      return;
    }

    this.#rankedPostNumber = data.post_number;
    const cited = data.cooked
      ? citedTopicsFromCooked(data.cooked)
      : citedTopicsFromRaw(data.raw);
    this.#ranker.add(++this.#currentTurn, "cited", cited);
    this.#showRanked();
  }

  async #load() {
    let topic;
    try {
      topic = await ajax(`/t/${this.args.topic.id}.json`);
    } catch {
      return;
    }

    this.#ranker.exclude(topic.id);
    // the first post is the search; every reply after it is a turn
    const [, ...posts] = await this.#allPosts(topic);
    const replies = posts.filter(
      (post) => post.user_id !== this.currentUser.id
    );
    replies.forEach((post, turn) => {
      this.#ranker.add(turn, "cited", citedTopicsFromCooked(post.cooked));
    });

    this.#currentTurn = Math.max(replies.length - 1, 0);
    this.#rankedPostNumber = posts.at(-1)?.post_number ?? 0;
    this.#loaded = true;
    this.#showRanked();
  }

  // A cited link has only a title, so each topic's details are looked up once.
  // The lookup leaves out muted topics, which are still listed by their title.
  async #showRanked() {
    const ranked = this.#ranker.rank(this.#currentTurn);
    const unknown = ranked
      .map((reference) => reference.topicId)
      .filter((id) => !this.#lookedUp.has(id));

    if (unknown.length) {
      try {
        const result = await ajax("/filter.json", {
          data: { q: `topic:${unknown.join(",")}` },
        });
        unknown.forEach((id) => this.#lookedUp.add(id));
        result.topic_list.topics.forEach((topic) =>
          this.#topics.set(topic.id, topic)
        );
      } catch {
        // listed by title until the next reply looks again
      }
    }

    this.references = ranked.map((reference) => {
      const topic = this.#topics.get(reference.topicId);
      return topic
        ? {
            ...reference,
            title: topic.title,
            categoryId: topic.category_id,
            bumpedAt: topic.bumped_at,
            replyCount: topic.posts_count - 1,
          }
        : reference;
    });
  }

  // the topic comes with only its first chunk of posts
  async #allPosts(topic) {
    const loaded = topic.post_stream.posts;
    const loadedIds = new Set(loaded.map((post) => post.id));
    const missing = topic.post_stream.stream.filter((id) => !loadedIds.has(id));
    if (missing.length === 0) {
      return loaded;
    }

    try {
      const more = await ajax(`/t/${topic.id}/posts.json`, {
        data: { post_ids: missing },
      });
      return [...loaded, ...more.post_stream.posts].sort(
        (a, b) => a.post_number - b.post_number
      );
    } catch {
      return loaded;
    }
  }

  <template>
    <AiSearchReferencesPanel @references={{this.references}} />
  </template>
}
