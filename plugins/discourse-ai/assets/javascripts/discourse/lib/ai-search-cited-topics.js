import { tracked } from "@glimmer/tracking";
import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import AiSearchReferences, {
  citedTopicsFromCooked,
  citedTopicsFromRaw,
} from "./ai-search-references.js";

/**
 * The topics a conversation continued from a combined search has cited, the
 * latest citations first, kept current as replies finish.
 */
export default class AiSearchCitedTopics {
  @service messageBus;

  @tracked references = [];

  #currentTurn = 0;
  #details = new Map();
  #lookedUp = new Set();
  #rankedPostNumber = 0;
  #ranker = new AiSearchReferences();
  #topic;

  constructor(owner, topic) {
    setOwner(this, owner);
    this.#topic = topic;
    this.messageBus.subscribe(this.#channel, this.onStream);
    this.#rankCitedSoFar();
  }

  get #channel() {
    return `discourse-ai/ai-bot/topic/${this.#topic.id}`;
  }

  teardown() {
    this.messageBus.unsubscribe(this.#channel, this.onStream);
  }

  // A reply still streaming when the page loaded finishes as the last post,
  // and fills in its own turn; any later reply starts a new one.
  @bind
  onStream(data) {
    if (!data?.done || !data.post_number) {
      return;
    }
    if (data.post_number < this.#rankedPostNumber) {
      return;
    }

    if (data.post_number > this.#rankedPostNumber) {
      this.#currentTurn++;
      this.#rankedPostNumber = data.post_number;
    }
    const cited = data.cooked
      ? citedTopicsFromCooked(data.cooked)
      : citedTopicsFromRaw(data.raw);
    this.#ranker.add(this.#currentTurn, "cited", cited);
    this.#showRanked();
  }

  // The topic view brings what has been cited so far, with each topic's
  // details, so nothing is loaded until a new reply cites more.
  #rankCitedSoFar() {
    const { replies = 0, topics: cited = [] } =
      this.#topic.ai_search_cited_topics || {};
    const turns = new Map();
    cited.forEach((topic) => {
      turns.set(topic.turn, [...(turns.get(topic.turn) ?? []), topic]);
    });
    turns.forEach((topics, turn) => {
      topics.forEach((topic) => {
        this.#lookedUp.add(topic.topic_id);
        this.#details.set(topic.topic_id, topic);
      });
      this.#ranker.add(
        turn,
        "cited",
        topics.map((topic) => ({
          topicId: topic.topic_id,
          title: topic.title,
          url: topic.url,
        }))
      );
    });

    this.#ranker.exclude(this.#topic.id);
    this.#currentTurn = Math.max(replies - 1, 0);
    this.#rankedPostNumber = this.#topic.highest_post_number ?? 0;
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
          this.#details.set(topic.id, {
            title: topic.title,
            category_id: topic.category_id,
            bumped_at: topic.bumped_at,
            reply_count: topic.posts_count - 1,
          })
        );
      } catch {
        // listed by title until the next reply looks again
      }
    }

    this.references = ranked.map((reference) => {
      const details = this.#details.get(reference.topicId);
      return details
        ? {
            ...reference,
            title: details.title,
            categoryId: details.category_id,
            bumpedAt: details.bumped_at,
            replyCount: details.reply_count,
          }
        : reference;
    });
  }
}
