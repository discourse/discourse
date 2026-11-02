import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import Category from "discourse/models/category";
import { CREATE_TOPIC, REPLY } from "discourse/models/composer";
import PhraseMatcher from "../lib/phrase-matcher.js";

// Without phrases, a trigger fires on pauses at most this often.
const NO_PHRASES_INTERVAL_MS = 15000;
// Attributes are capped so that a tag without its closing bracket can't make
// scanning quadratic.
const QUOTE_TAG_REGEXP = /\[quote(?:=[^\]]{0,300})?\]|\[\/quote\]/gi;
const BLOCKQUOTE_LINE_REGEXP = /^[ \t]*>.*$/gm;
const HTML_COMMENT_START = "<!--";
const HTML_COMMENT_END = "-->";
const COMPOSER_ACTIONS = { [CREATE_TOPIC]: "create_topic", [REPLY]: "reply" };
// For failed requests that don't say how long to wait.
const RETRY_AFTER_ERROR_MS = 15000;

function stripHtmlComments(text) {
  const parts = [];
  let position = 0;
  let start;

  while ((start = text.indexOf(HTML_COMMENT_START, position)) !== -1) {
    const end = text.indexOf(
      HTML_COMMENT_END,
      start + HTML_COMMENT_START.length
    );
    if (end === -1) {
      break;
    }

    parts.push(text.slice(position, start));
    position = end + HTML_COMMENT_END.length;
  }

  parts.push(text.slice(position));
  return parts.join("");
}

// Removes balanced quote blocks, nested ones included, in one pass. An
// unclosed quote is kept as text.
function stripQuoteBlocks(text) {
  const parts = [];
  const openQuotes = [];
  let position = 0;

  for (const match of text.matchAll(QUOTE_TAG_REGEXP)) {
    const tag = match[0];
    parts.push(text.slice(position, match.index));
    position = match.index + tag.length;

    if (tag.startsWith("[/")) {
      if (openQuotes.length) {
        parts.length = openQuotes.pop();
      } else {
        parts.push(tag);
      }
    } else {
      openQuotes.push(parts.length);
      parts.push(tag);
    }
  }

  parts.push(text.slice(position));
  return parts.join("");
}

// Must match `ComposerSnapshot.own_text` on the server.
export function ownText({ title, reply }) {
  const body = stripQuoteBlocks(stripHtmlComments(reply || "")).replace(
    BLOCKQUOTE_LINE_REGEXP,
    ""
  );

  return [title, body].filter(Boolean).join("\n");
}

function composerAction(composer) {
  const action = COMPOSER_ACTIONS[composer?.action];

  // A restored reply loads its target post after opening.
  if (
    action &&
    composer.viewOpenOrFullscreen &&
    !composer.privateMessage &&
    !composer.loading
  ) {
    return action;
  }
}

function retryDelayMs(error) {
  const waitSeconds = error?.jqXHR?.responseJSON?.extras?.wait_seconds;
  return waitSeconds ? waitSeconds * 1000 : RETRY_AFTER_ERROR_MS;
}

function matchesCategory(trigger, categoryId) {
  if (!trigger.category_ids.length) {
    return true;
  }

  let category = Category.findById(categoryId);
  if (!category) {
    // Not loaded in the browser, so the server decides.
    return !!categoryId;
  }

  if (!trigger.include_subcategories) {
    return trigger.category_ids.includes(category.id);
  }

  while (category) {
    if (trigger.category_ids.includes(category.id)) {
      return true;
    }
    category = category.parentCategory;
  }

  return false;
}

export default class WorkflowsComposerPaused extends Service {
  @service site;
  @service siteSettings;
  @service workflowsComposerSession;

  #checking = false;
  #matcher = new PhraseMatcher();
  #nextComposer = null;
  #retryAt = 0;
  #sessions = new WeakMap();
  #triggers = this.site.composer_paused_workflows || [];

  willDestroy() {
    super.willDestroy(...arguments);
    this.#matcher.destroy();
  }

  // Pauses that come in during a check are folded into one check of the latest draft, so there
  // is at most one request in flight.
  async typingPaused(composer) {
    this.#nextComposer = composer;
    if (this.#checking) {
      return;
    }

    this.#checking = true;
    try {
      while (this.#nextComposer) {
        const next = this.#nextComposer;
        this.#nextComposer = null;
        await this.#check(next);
      }
    } finally {
      this.#checking = false;
    }
  }

  async #check(composer) {
    const action = composerAction(composer);
    if (!action || Date.now() < this.#retryAt) {
      return;
    }

    // the server never matches past what a post can hold
    const draft = {
      title: composer.title?.slice(0, this.siteSettings.max_topic_title_length),
      reply: composer.reply?.slice(0, this.siteSettings.max_post_length),
    };
    const text = ownText(draft);
    const categoryId = composer.topic?.category_id ?? composer.categoryId;
    const sessionId = this.workflowsComposerSession.idFor(composer);
    const triggers = this.#triggers
      .filter(
        (trigger) =>
          trigger.composer_actions.includes(action) &&
          matchesCategory(trigger, categoryId)
      )
      .map((trigger) => ({
        trigger,
        state: this.#stateFor(composer, trigger),
      }));

    const unmatched = new Set(
      triggers.flatMap(({ trigger, state }) =>
        trigger.patterns.filter((source) => !state.matched.has(source))
      )
    );
    const matched = await this.#matcher.match(text, [...unmatched]);

    // The composer may have closed or reopened while matching.
    if (
      composerAction(composer) !== action ||
      this.workflowsComposerSession.idFor(composer) !== sessionId
    ) {
      return;
    }

    const now = Date.now();
    const newMatches = [];
    const noPhraseStates = [];

    for (const { trigger, state } of triggers) {
      if (!trigger.patterns.length) {
        noPhraseStates.push(state);
        continue;
      }

      const sources = trigger.patterns.filter(
        (source) => matched.has(source) && !state.matched.has(source)
      );
      if (sources.length) {
        newMatches.push({ state, sources });
      }
    }

    const noPhrasesDue = noPhraseStates.some(
      (state) =>
        text !== state.text && now - state.firedAt >= NO_PHRASES_INTERVAL_MS
    );
    if (!newMatches.length && !noPhrasesDue) {
      return;
    }

    // A trigger only counts as fired once the server answered, so it can fire again after an
    // error. A nudge is best effort, so an error must never interrupt writing.
    try {
      await this.#post(composer, draft, action);
      newMatches.forEach(({ state, sources }) =>
        sources.forEach((source) => state.matched.add(source))
      );
      // The server checks every trigger on each request, so those without phrases restart their
      // interval together.
      noPhraseStates.forEach((state) => {
        state.text = text;
        state.firedAt = now;
      });
    } catch (error) {
      this.#retryAt = Date.now() + retryDelayMs(error);
    }
  }

  // State lives in the composer session, so reopening the composer starts over.
  #stateFor(composer, trigger) {
    const sessionId = this.workflowsComposerSession.idFor(composer);
    let session = this.#sessions.get(composer);
    if (session?.id !== sessionId) {
      session = { id: sessionId, states: new Map() };
      this.#sessions.set(composer, session);
    }

    const key = `${trigger.workflow_id}:${trigger.trigger_node_id}`;
    if (!session.states.has(key)) {
      session.states.set(key, {
        matched: new Set(),
        text: null,
        firedAt: -Infinity,
      });
    }
    return session.states.get(key);
  }

  #post(composer, draft, action) {
    return ajax("/discourse-workflows/trigger-composer-paused", {
      type: "POST",
      data: {
        draft_key: composer.draftKey,
        session_id: this.workflowsComposerSession.idFor(composer),
        composer_action: action,
        title: draft.title,
        raw: draft.reply,
        category_id: composer.categoryId,
        topic_id: composer.topic?.id,
        // A reply targets `post`; `reply_to_post_number` only changes when a
        // post is edited.
        reply_to_post_number: composer.post?.post_number,
      },
    });
  }
}
