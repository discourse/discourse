import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import Category from "discourse/models/category";
import { CREATE_TOPIC, REPLY } from "discourse/models/composer";

// Without phrases, a trigger fires on pauses at most this often.
const NO_PHRASES_INTERVAL_MS = 15000;
// Attributes are capped so that a tag without its closing bracket can't make
// scanning quadratic.
const QUOTE_TAG_REGEXP = /\[quote(?:=[^\]]{0,300})?\]|\[\/quote\]/gi;
const BLOCKQUOTE_LINE_REGEXP = /^[ \t]*>.*$/gm;
const HTML_COMMENT_START = "<!--";
const HTML_COMMENT_END = "-->";
const COMPOSER_ACTIONS = { [CREATE_TOPIC]: "create_topic", [REPLY]: "reply" };
// The server declined these phrases, so asking again won't change the answer.
const DECLINED_STATUS = 422;

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

function compile(patterns) {
  return patterns.flatMap((source) => {
    try {
      return [{ source, regexp: new RegExp(source, "iu") }];
    } catch {
      // Regular expression phrases may use syntax only the server supports.
      return [];
    }
  });
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

  #states = new WeakMap();
  #sessionIds = new WeakMap();
  #triggers = (this.site.composer_paused_workflows || []).map((trigger) => ({
    ...trigger,
    hasPhrases: trigger.patterns.length > 0,
    regexps: compile(trigger.patterns),
  }));

  typingPaused(composer) {
    const action = COMPOSER_ACTIONS[composer?.action];
    if (!action || !composer.viewOpenOrFullscreen || composer.privateMessage) {
      return;
    }

    // the server never matches past what a post can hold
    const draft = {
      title: composer.title?.slice(0, this.siteSettings.max_topic_title_length),
      reply: composer.reply?.slice(0, this.siteSettings.max_post_length),
    };
    const text = ownText(draft);
    const categoryId = composer.topic?.category_id ?? composer.categoryId;

    for (const trigger of this.#triggers) {
      if (
        !trigger.composer_actions.includes(action) ||
        !matchesCategory(trigger, categoryId)
      ) {
        continue;
      }

      const sources = this.#newMatches(composer, trigger, text);
      if (sources) {
        this.#fire(composer, draft, trigger, action, sources);
      }
    }
  }

  // State lives on the composer model, so reopening the composer starts over.
  // Returns the newly matched patterns, or null when there is nothing to send.
  #newMatches(composer, trigger, text) {
    const state = this.#stateFor(composer, trigger);

    if (trigger.hasPhrases) {
      const sources = trigger.regexps
        .filter(
          ({ source, regexp }) =>
            !state.matched.has(source) &&
            !state.pending.has(source) &&
            regexp.test(text)
        )
        .map(({ source }) => source);
      return sources.length ? sources : null;
    }

    const now = Date.now();
    if (text === state.text || now - state.firedAt < NO_PHRASES_INTERVAL_MS) {
      return null;
    }

    state.text = text;
    state.firedAt = now;
    return [];
  }

  #stateFor(composer, trigger) {
    let states = this.#states.get(composer);
    if (!states) {
      states = new Map();
      this.#states.set(composer, states);
    }

    const key = `${trigger.workflow_id}:${trigger.trigger_node_id}`;
    if (!states.has(key)) {
      states.set(key, {
        matched: new Set(),
        pending: new Set(),
        text: null,
        firedAt: -Infinity,
      });
    }
    return states.get(key);
  }

  #sessionIdFor(composer) {
    if (!this.#sessionIds.has(composer)) {
      this.#sessionIds.set(composer, crypto.randomUUID());
    }
    return this.#sessionIds.get(composer);
  }

  // A phrase only counts as fired once the server answered, so a failed
  // request can try again on the next pause.
  async #fire(composer, draft, trigger, action, sources) {
    const state = this.#stateFor(composer, trigger);
    sources.forEach((source) => state.pending.add(source));

    try {
      await this.#post(composer, draft, trigger, action);
      sources.forEach((source) => state.matched.add(source));
    } catch (error) {
      if (error?.jqXHR?.status === DECLINED_STATUS) {
        sources.forEach((source) => state.matched.add(source));
      }
      // A nudge is best effort; an error must never interrupt writing.
    } finally {
      sources.forEach((source) => state.pending.delete(source));
    }
  }

  #post(composer, draft, trigger, action) {
    return ajax("/discourse-workflows/trigger-composer-paused", {
      type: "POST",
      data: {
        workflow_id: trigger.workflow_id,
        trigger_node_id: trigger.trigger_node_id,
        draft_key: composer.draftKey,
        session_id: this.#sessionIdFor(composer),
        composer_action: action,
        title: draft.title,
        raw: draft.reply,
        category_id: composer.categoryId,
        topic_id: composer.topic?.id,
        reply_to_post_number: composer.post?.post_number,
      },
    });
  }
}
