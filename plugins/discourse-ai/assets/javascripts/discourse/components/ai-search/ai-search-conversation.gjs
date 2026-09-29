import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { eq, not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DCookText from "discourse/ui-kit/d-cook-text";
import DExpandingTextArea from "discourse/ui-kit/d-expanding-text-area";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import AiSearchReferences, {
  citedTopicsFromCooked,
  citedTopicsFromRaw,
} from "../../lib/ai-search-references";
import { withScope } from "../../lib/ai-search-scope";
import {
  keywordSearch,
  semanticSearch,
} from "../../services/ai-search-session";
import AiBlinkingAnimation from "../ai-blinking-animation";
import AiSearchReferencesPanel from "./ai-search-references-panel";

function referenceFromPost(post) {
  return {
    topicId: post.topic_id,
    title: post.topic?.title,
    url: post.url,
    categoryId: post.topic?.category_id,
    excerpt: post.blurb,
  };
}

/**
 * A combined search continued as a conversation. The first answer leads, and
 * the references beside it are reranked as each question is asked and answered.
 */
export default class AiSearchConversation extends Component {
  @service currentUser;
  @service messageBus;
  @service siteSettings;

  @tracked loading = true;
  @tracked query = "";
  @tracked opening = null;
  @tracked turns = [];
  @tracked composerValue = "";
  @tracked postingFollowUp = false;
  @tracked references = [];

  #ranker = new AiSearchReferences();
  #currentTurn = 0;

  constructor() {
    super(...arguments);
    this.#load();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe(this.#channel, this.onStream);
  }

  get showPendingReply() {
    return this.turns.at(-1)?.kind === "question";
  }

  get isAwaitingReply() {
    const last = this.turns.at(-1);
    return last?.kind === "question" || Boolean(last?.streaming);
  }

  get #channel() {
    return `discourse-ai/ai-bot/topic/${this.args.topicId}`;
  }

  @action
  updateComposer(event) {
    this.composerValue = event.target.value;
  }

  @action
  composerKeydown(event) {
    if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) {
      this.submitComposer(event);
    }
  }

  @action
  async submitComposer(event) {
    event.preventDefault();
    const question = this.composerValue.trim();
    if (!question || this.postingFollowUp || this.isAwaitingReply) {
      return;
    }

    const turn = ++this.#currentTurn;
    this.postingFollowUp = true;
    this.#replaceTurn({
      key: `q${turn}`,
      kind: "question",
      raw: question,
      turn,
    });
    this.composerValue = "";
    this.#rankQuestion(question, turn);

    try {
      await ajax("/posts", {
        type: "POST",
        data: { raw: question, topic_id: this.args.topicId },
      });
    } catch (error) {
      this.turns = this.turns.slice(0, -1);
      this.composerValue = question;
      this.#currentTurn--;
      popupAjaxError(error);
    } finally {
      this.postingFollowUp = false;
    }
  }

  @bind
  onStream(data) {
    if (!data || data.noop || !data.post_id || data.post_number <= 2) {
      return;
    }

    const existing = this.turns.find((turn) => turn.postId === data.post_id);
    // the closing message carries only the cooked post, and it is replayed
    // to anyone who opens the conversation soon after
    const updated = {
      key: `a${data.post_id}`,
      kind: "answer",
      postId: data.post_id,
      turn: existing?.turn ?? this.#currentTurn,
      raw: data.raw ?? existing?.raw ?? "",
      cooked: data.cooked ?? (data.raw ? null : existing?.cooked),
      streaming: !data.done,
    };
    this.#replaceTurn(updated);

    if (data.done) {
      const cited = updated.cooked
        ? citedTopicsFromCooked(updated.cooked)
        : citedTopicsFromRaw(updated.raw);
      this.#ranker.add(updated.turn, "cited", cited);
      this.references = this.#ranker.rank(this.#currentTurn);
    }
  }

  async #load() {
    this.messageBus.subscribe(this.#channel, this.onStream, -2);

    let topic;
    try {
      topic = await ajax(`/t/${this.args.topicId}.json`);
    } catch (error) {
      popupAjaxError(error);
      return;
    } finally {
      this.loading = false;
    }

    this.#ranker.exclude(topic.id);
    const [queryPost, answerPost, ...rest] = await this.#allPosts(topic);
    this.query = queryPost?.cooked
      ? new DOMParser().parseFromString(queryPost.cooked, "text/html").body
          .textContent
      : topic.title;
    this.opening = answerPost;

    const turns = [];
    let turn = 0;
    rest.forEach((post) => {
      if (post.user_id === this.currentUser.id) {
        turn++;
        turns.push({
          key: `q${turn}`,
          kind: "question",
          cooked: post.cooked,
          raw: post.cooked,
          turn,
        });
      } else if (!turns.some((existing) => existing.postId === post.id)) {
        turns.push({
          key: `a${post.id}`,
          kind: "answer",
          postId: post.id,
          cooked: post.cooked,
          turn,
        });
      }
    });

    // A reply still streaming while the topic loaded is further along than the
    // loaded copy; one that finished is better loaded, which is cooked. Either
    // way it answers the latest question.
    const streaming = this.turns
      .filter((existing) => existing.postId && existing.streaming)
      .map((existing) => ({ ...existing, turn }));
    this.turns = [
      ...turns.filter(
        (existing) => !streaming.some((s) => s.postId === existing.postId)
      ),
      ...streaming,
    ];
    this.#currentTurn = turn;

    await this.#rankHistory(answerPost, turns);
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

  async #rankHistory(answerPost, turns) {
    this.#ranker.add(0, "cited", citedTopicsFromCooked(answerPost?.cooked));
    await this.#rankQuestion(this.query, 0, { rank: false });

    for (const turn of turns) {
      if (turn.kind === "question") {
        const text = new DOMParser().parseFromString(turn.cooked, "text/html")
          .body.textContent;
        await this.#rankQuestion(text, turn.turn, { rank: false });
      } else {
        this.#ranker.add(
          turn.turn,
          "cited",
          citedTopicsFromCooked(turn.cooked)
        );
      }
    }

    this.references = this.#ranker.rank(this.#currentTurn);
  }

  async #rankQuestion(question, turn, { rank = true } = {}) {
    const scoped = withScope(question, this.args.scope);
    const semanticInScope = !["topic", "messages"].includes(
      this.args.scope?.split(":")[0]
    );
    const [keyword, semantic] = await Promise.all([
      keywordSearch(scoped),
      this.siteSettings.ai_embeddings_semantic_search_enabled && semanticInScope
        ? semanticSearch(scoped)
        : [],
    ]);
    this.#ranker.add(turn, "keyword", keyword.map(referenceFromPost));
    this.#ranker.add(turn, "semantic", semantic.map(referenceFromPost));
    if (rank) {
      this.references = this.#ranker.rank(this.#currentTurn);
    }
  }

  #replaceTurn(updated) {
    const index = this.turns.findIndex((turn) => turn.key === updated.key);
    this.turns =
      index === -1
        ? [...this.turns, updated]
        : this.turns.map((turn, i) => (i === index ? updated : turn));
  }

  <template>
    <DConditionalLoadingSpinner @condition={{this.loading}}>
      <div class="ai-search__heading">
        <h2 class="ai-search__query-text">{{this.query}}</h2>
      </div>

      <div class="ai-search__conversation">
        <div aria-live="polite" class="ai-search__thread">
          {{#if this.opening}}
            <article class="ai-search__turn --op">
              <div class="cooked">{{trustHTML this.opening.cooked}}</div>
            </article>
          {{/if}}

          {{#each this.turns key="key" as |turn|}}
            {{#if (eq turn.kind "question")}}
              <div class="ai-search__turn --question">
                {{dAvatar this.currentUser imageSize="small"}}
                {{#if turn.cooked}}
                  <div class="cooked">{{trustHTML turn.cooked}}</div>
                {{else}}
                  <p>{{turn.raw}}</p>
                {{/if}}
              </div>
            {{else}}
              <article
                aria-busy={{if turn.streaming "true"}}
                class={{dConcatClass
                  "ai-search__turn --answer"
                  (if turn.streaming "streaming")
                  "streamable-content"
                }}
              >
                {{#if turn.cooked}}
                  <div class="cooked">{{trustHTML turn.cooked}}</div>
                {{else}}
                  <DCookText class="cooked" @rawText={{turn.raw}} />
                {{/if}}
              </article>
            {{/if}}
          {{/each}}

          {{#if this.showPendingReply}}
            <div class="ai-search__turn --answer --pending">
              <AiBlinkingAnimation />
            </div>
          {{/if}}

          <form class="ai-search__composer" {{on "submit" this.submitComposer}}>
            <DExpandingTextArea
              aria-label={{i18n "discourse_ai.ai_search.composer_label"}}
              placeholder={{i18n "discourse_ai.ai_search.composer_placeholder"}}
              @input={{this.updateComposer}}
              @rows="2"
              @value={{this.composerValue}}
              {{on "keydown" this.composerKeydown}}
            />
            <DButton
              class="btn-primary ai-search__composer-submit"
              @disabled={{or
                this.postingFollowUp
                this.isAwaitingReply
                (not this.composerValue)
              }}
              @icon="paper-plane"
              @label="discourse_ai.ai_search.send"
              @type="submit"
            />
          </form>
        </div>

        <AiSearchReferencesPanel @references={{this.references}} />
      </div>
    </DConditionalLoadingSpinner>
  </template>
}
