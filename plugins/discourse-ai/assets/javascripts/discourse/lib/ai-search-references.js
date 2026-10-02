const RANK_K = 10;
const TURN_DECAY = 0.6;

export const SIGNAL_WEIGHTS = {
  cited: 3,
  semantic: 1.2,
  keyword: 1,
};

const TOPIC_URL_PATTERN = /\/t\/(?:[^/\s)?#]+\/)?(\d+)/;
const MARKDOWN_LINK_PATTERN = /\[([^\]]+)\]\(([^)\s]+)\)/g;

export function topicIdFromUrl(url) {
  const match = url?.match(TOPIC_URL_PATTERN);
  return match ? parseInt(match[1], 10) : null;
}

/**
 * Topics a reply links to, titled by their link text, in order of first mention.
 */
export function citedTopicsFromRaw(raw) {
  const seen = new Set();
  const cited = [];

  for (const [, text, url] of (raw || "").matchAll(MARKDOWN_LINK_PATTERN)) {
    const topicId = topicIdFromUrl(url);
    if (topicId && !seen.has(topicId)) {
      seen.add(topicId);
      cited.push({ topicId, title: text, url });
    }
  }

  return cited;
}

/**
 * Accumulates evidence for topics across a conversation's turns and ranks them
 * with a reciprocal-rank score, so a topic that keeps surfacing rises while one
 * only relevant to an early turn fades rather than vanishing.
 */
export default class AiSearchReferences {
  #entries = new Map();
  #previousOrder = [];
  #excludedTopicIds = new Set();

  exclude(topicId) {
    this.#excludedTopicIds.add(topicId);
    this.#entries.delete(topicId);
  }

  /**
   * @param {number} turn conversation turn the evidence belongs to
   * @param {"cited"|"semantic"|"keyword"} kind
   * @param {Array<{topicId: number, title: string, url: string, categoryId?: number, excerpt?: string}>} items best first
   */
  add(turn, kind, items) {
    items.forEach((item, index) => {
      if (!item.topicId || this.#excludedTopicIds.has(item.topicId)) {
        return;
      }

      const entry = this.#entries.get(item.topicId) || {
        topicId: item.topicId,
        signals: [],
      };
      entry.title ||= item.title;
      entry.url ||= item.url;
      entry.categoryId ??= item.categoryId;
      entry.excerpt ||= item.excerpt;
      entry.signals.push({ turn, kind, rank: index + 1 });
      this.#entries.set(item.topicId, entry);
    });
  }

  /**
   * Ranks every topic as of `currentTurn` and reports how each moved since the
   * previous call.
   */
  rank(currentTurn, limit = 12) {
    const ranked = [...this.#entries.values()]
      .map((entry) => ({
        ...entry,
        score: this.#score(entry, currentTurn),
        kinds: [...new Set(entry.signals.map((signal) => signal.kind))],
        citedNow: entry.signals.some(
          (signal) => signal.kind === "cited" && signal.turn === currentTurn
        ),
      }))
      .sort((a, b) => b.score - a.score || a.topicId - b.topicId)
      .slice(0, limit);

    const previous = this.#previousOrder;
    ranked.forEach((entry, index) => {
      const previousIndex = previous.indexOf(entry.topicId);
      entry.isNew = previous.length > 0 && previousIndex === -1;
      entry.movement = previousIndex === -1 ? 0 : previousIndex - index;
    });
    this.#previousOrder = ranked.map((entry) => entry.topicId);

    return ranked;
  }

  #score(entry, currentTurn) {
    return entry.signals.reduce(
      (total, signal) =>
        total +
        (SIGNAL_WEIGHTS[signal.kind] / (RANK_K + signal.rank)) *
          TURN_DECAY ** (currentTurn - signal.turn),
      0
    );
  }
}

/**
 * Topics a cooked post links to, titled by their link text.
 */
export function citedTopicsFromCooked(cooked) {
  const doc = new DOMParser().parseFromString(cooked || "", "text/html");
  const seen = new Set();
  const cited = [];

  doc.querySelectorAll("a[href]").forEach((link) => {
    const url = link.getAttribute("href");
    const topicId = topicIdFromUrl(url);
    if (topicId && !seen.has(topicId)) {
      seen.add(topicId);
      cited.push({ topicId, title: link.textContent.trim(), url });
    }
  });

  return cited;
}
