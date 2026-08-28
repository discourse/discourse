import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { MODIFIER_REGEXP } from "discourse/components/search-menu";
import escapeRegExp from "discourse/lib/escape-regexp";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import shortcutLabel from "../lib/shortcut-label";
import { ASK_MODE, SEARCH_MODE } from "../services/discobot-discoveries";

function shortcutHint(...keys) {
  return i18n("discourse_ai.discobot_discoveries.shortcut_hint", {
    shortcut: shortcutLabel(...keys),
  });
}

function operatorPattern(operator, flags) {
  return new RegExp(`(?:^|\\s)${escapeRegExp(operator)}(?=\\s|$)`, flags);
}

function categoryOperator(category) {
  if (!category) {
    return null;
  }

  return category.parentCategory
    ? `#${category.parentCategory.slug}:${category.slug}`
    : `#${category.slug}`;
}

export default class AiDiscoveriesSearchOptions extends Component {
  @service discobotDiscoveries;
  @service search;

  // even before the scope itself is released.
  @tracked scopedTerm = null;

  get query() {
    return this.search.activeGlobalSearchTerm?.trim();
  }

  // Only a topic scopes the search itself; category and tag pages set a context
  // but still search globally, so they get no option of their own here. It stays
  // offered while scoped, as the way back and forth between the two.
  get inTopic() {
    return this.search.searchContext?.type === "topic";
  }

  get inPMInbox() {
    return this.search.searchContext?.type === "private_messages";
  }

  // A topic scopes the search itself and the inbox lives on the menu; the rest
  // narrow by putting operators in the term, where the reader can see them.
  // A tag page inside a category contributes two, so this is always a list.
  get contextKind() {
    switch (this.search.searchContext?.type) {
      case "user":
        return "user";
      case "category":
        return "category";
      case "tag":
      case "tagIntersection":
        return "tag";
      default:
        return null;
    }
  }

  get contextOperators() {
    const context = this.search.searchContext;

    switch (context?.type) {
      case "user":
        return context.user?.username ? [`@${context.user.username}`] : [];
      case "category":
        return [categoryOperator(context.category)].filter(Boolean);
      case "tag":
        return context.name ? [`#${context.name}`] : [];
      case "tagIntersection": {
        // several tags intersect with `tags:`, a single one keeps the `#` form
        const tags = context.additionalTags?.length
          ? [`tags:${[context.tagId, ...context.additionalTags].join("+")}`]
          : [context.tagId && `#${context.tagId}`];

        return [...tags, categoryOperator(context.category)].filter(Boolean);
      }
      default:
        return [];
    }
  }

  get contextOperator() {
    return this.contextOperators.join(" ") || null;
  }

  get contextLabel() {
    if (this.contextKind === "user") {
      return i18n("discourse_ai.discobot_discoveries.search_user_posts", {
        username: this.search.searchContext.user?.username,
      });
    }

    return i18n("discourse_ai.discobot_discoveries.search_in_context", {
      name: this.contextOperator,
    });
  }

  // Read off the term rather than remembered: the operators are visible in the
  // input, so they stay recognised however they got there — picked here, typed
  // by hand, or carried in from an earlier search. Order is not part of it, so
  // each is looked for on its own.
  get termNarrowedToContext() {
    const operators = this.contextOperators;
    if (operators.length === 0) {
      return false;
    }

    return operators.every((operator) =>
      operatorPattern(operator, "i").test(this.query || "")
    );
  }

  get contextActive() {
    return this.termNarrowedToContext;
  }

  get showContextOption() {
    if (!this.contextOperator) {
      return false;
    }

    return this.contextActive || !this.query?.match(MODIFIER_REGEXP);
  }

  get termWithoutContext() {
    return this.contextOperators
      .reduce(
        (term, operator) => term.replace(operatorPattern(operator, "gi"), " "),
        this.query || ""
      )
      .replace(/\s+/g, " ")
      .trim();
  }

  // The inbox scope lives on the menu rather than in the term, so this reads the
  // menu's own state — which is already on for a fresh search from an inbox.
  get messagesActive() {
    return Boolean(this.args.inPMInboxContext);
  }

  get scopedToTopic() {
    return this.search.inTopicContext && this.scopedTerm === this.query;
  }

  get askedActive() {
    return (
      !this.scopedToTopic &&
      !this.contextActive &&
      !this.messagesActive &&
      this.discobotDiscoveries.searchMode === ASK_MODE
    );
  }

  // The widest reach, so it only holds when nothing narrower does — every other
  // option runs a topic search too, and would otherwise light this one up with it.
  get allTopicsActive() {
    if (
      this.askedActive ||
      this.scopedToTopic ||
      this.contextActive ||
      this.messagesActive
    ) {
      return false;
    }

    return this.discobotDiscoveries.searchMode === SEARCH_MODE;
  }

  // Only the options that have one: scope has never had a keybinding, so the
  // three that map to enter, shift+enter and ctrl/cmd+enter say so and the rest
  // stay quiet rather than inventing hints.
  get allTopicsTitle() {
    return this.allTopicsActive ? shortcutHint("enter") : null;
  }

  get askTitle() {
    return this.askedActive
      ? shortcutHint("enter")
      : shortcutHint("shift", "enter");
  }

  get advancedTitle() {
    return i18n("discourse_ai.discobot_discoveries.advanced_with_shortcut", {
      shortcut: shortcutHint("meta", "enter"),
    });
  }

  @action
  searchAllTopics() {
    this.discobotDiscoveries.selectSearchMode(SEARCH_MODE);
    // choosing the indexed results means the answer is no longer what was asked for
    this.discobotDiscoveries.dismissDiscovery();
    // the input no longer carries a chip to step back out of a scope, so the
    // wider reach has to release them
    this.args.clearTopicContext?.();
    this.args.clearPMInboxContext?.();

    // the wider reach drops the operator that was narrowing it
    if (this.termNarrowedToContext) {
      this.args.searchTermChanged?.(this.termWithoutContext, {
        searchTopics: true,
      });
      return;
    }

    this.args.updateTypeFilter?.(null);
    this.args.triggerSearch?.();
  }

  @action
  searchInContext() {
    this.discobotDiscoveries.selectSearchMode(SEARCH_MODE);
    this.discobotDiscoveries.dismissDiscovery();
    this.args.clearTopicContext?.();
    this.args.clearPMInboxContext?.();
    // Mirrors the native shortcut: the operators go in the term. Only the ones
    // missing, so picking it twice is a no-op and a term that already carries
    // one of them keeps just the one.
    const missing = this.contextOperators.filter(
      (operator) => !operatorPattern(operator, "i").test(this.query || "")
    );
    const term = missing.length
      ? [this.query, ...missing].join(" ")
      : this.query;

    this.args.searchTermChanged?.(term, { searchTopics: true });
  }

  @action
  searchMessages() {
    this.discobotDiscoveries.selectSearchMode(SEARCH_MODE);
    this.discobotDiscoveries.dismissDiscovery();
    this.args.clearTopicContext?.();
    this.args.searchTermChanged?.(this.query, {
      searchTopics: true,
      setPMInboxContext: true,
    });
  }

  @action
  searchThisTopic() {
    this.discobotDiscoveries.selectSearchMode(SEARCH_MODE);
    this.scopedTerm = this.query;
    this.discobotDiscoveries.dismissDiscovery();
    this.args.searchTermChanged?.(this.query, {
      searchTopics: true,
      setTopicContext: true,
    });
  }

  @action
  ask() {
    this.args.clearTopicContext?.();
    this.args.clearPMInboxContext?.();

    const question = this.termNarrowedToContext
      ? this.termWithoutContext
      : this.query;

    if (question !== this.query) {
      this.args.searchTermChanged?.(question, { searchTopics: true });
    }

    this.discobotDiscoveries.triggerDiscovery(question);
  }

  <template>
    {{#if this.query}}
      <div class="ai-discoveries-search-options">
        {{! the narrowest scope leads, since it is the one the page is about }}
        {{#if this.inTopic}}
          <DButton
            class="btn-default btn-small ai-discoveries-search-options__option --topic
              {{if this.scopedToTopic 'is-active'}}"
            @icon="magnifying-glass"
            @label="discourse_ai.discobot_discoveries.search_this_topic"
            @action={{this.searchThisTopic}}
          />
        {{/if}}
        {{#if this.showContextOption}}
          <DButton
            class="btn-default btn-small ai-discoveries-search-options__option --{{this.contextKind}}
              {{if this.contextActive 'is-active'}}"
            @icon="magnifying-glass"
            @translatedLabel={{this.contextLabel}}
            @action={{this.searchInContext}}
          />
        {{/if}}
        {{#if this.inPMInbox}}
          <DButton
            class="btn-default btn-small ai-discoveries-search-options__option --messages
              {{if this.messagesActive 'is-active'}}"
            @icon="magnifying-glass"
            @label="discourse_ai.discobot_discoveries.search_messages"
            @action={{this.searchMessages}}
          />
        {{/if}}
        {{! only the options with a keybinding say so; the scopes have none to
            report, and an invented hint is worse than none }}
        <DButton
          class="btn-default btn-small ai-discoveries-search-options__option --search
            {{if this.allTopicsActive 'is-active'}}"
          @icon="magnifying-glass"
          @label="discourse_ai.discobot_discoveries.search_all_topics"
          @translatedTitle={{this.allTopicsTitle}}
          @action={{this.searchAllTopics}}
        />
        <DButton
          class="btn-default btn-small ai-discoveries-search-options__option --ask
            {{if this.askedActive 'is-active'}}"
          @icon="far-discobot"
          @label="discourse_ai.discobot_discoveries.ask_ai"
          @translatedTitle={{this.askTitle}}
          @action={{this.ask}}
        />
        {{#if this.allTopicsActive}}
          <DButton
            class="btn-default btn-small ai-discoveries-search-options__option --advanced"
            @icon="sliders"
            @translatedTitle={{this.advancedTitle}}
            @ariaLabel="search.open_advanced"
            @action={{@openAdvancedSearch}}
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
