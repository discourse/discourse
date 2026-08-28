import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action, get } from "@ember/object";
import { service } from "@ember/service";
import { MODIFIER_REGEXP } from "discourse/components/search-menu";
import escapeRegExp from "discourse/lib/escape-regexp";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import shortcutLabel from "../lib/shortcut-label";

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
  @service currentUser;
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
    const context = this.search.searchContext;

    switch (context?.type) {
      case "user":
        return "user";
      case "category":
        return "category";
      case "tag":
      case "tagIntersection":
        return "tag";
      case "private_messages":
        return context.group ? "messages" : null;
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
      case "private_messages":
        return context.group?.name
          ? [`group_messages:${context.group.name}`]
          : [];
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

    if (this.contextKind === "messages") {
      return i18n("discourse_ai.discobot_discoveries.search_group_messages", {
        group: this.search.searchContext.group.name,
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

  // A receipt rather than an armed mode: enter always runs the indexed search,
  // so the only thing worth marking is which option produced what is showing.
  get askedActive() {
    return (
      Boolean(this.query) && this.discobotDiscoveries.lastQuery === this.query
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

    return Boolean(this.args.searchTopics);
  }

  // Only the options that have one: scope has never had a keybinding, so the
  // three that map to enter, shift+enter and ctrl/cmd+enter say so and the rest
  // stay quiet rather than inventing hints.
  // `get` rather than a native read: the option lives on a classic object, so
  // the row would not reorder or relabel when it changes.
  get asksByDefault() {
    return Boolean(get(this.currentUser, "user_option.ai_ask_ai_default"));
  }

  get options() {
    const scopes = [];

    if (this.inTopic) {
      scopes.push({
        kind: "topic",
        icon: "magnifying-glass",
        label: "discourse_ai.discobot_discoveries.search_this_topic",
        active: this.scopedToTopic,
        action: this.searchThisTopic,
      });
    }

    if (this.showContextOption) {
      scopes.push({
        kind: this.contextKind,
        icon: "magnifying-glass",
        translatedLabel: this.contextLabel,
        active: this.contextActive,
        action: this.searchInContext,
      });
    }

    if (this.inPMInbox && this.contextKind !== "messages") {
      scopes.push({
        kind: "messages",
        icon: "magnifying-glass",
        label: "discourse_ai.discobot_discoveries.search_messages",
        active: this.messagesActive,
        action: this.searchMessages,
      });
    }

    const { search, ask } = this.resolveOptions;

    return this.asksByDefault
      ? [ask, ...scopes, search]
      : [...scopes, search, ask];
  }

  get resolveOptions() {
    const search = {
      kind: "search",
      icon: "magnifying-glass",
      label: "discourse_ai.discobot_discoveries.search_all_topics",
      title: this.allTopicsTitle,
      active: this.allTopicsActive,
      action: this.searchAllTopics,
    };
    const ask = {
      kind: "ask",
      icon: "far-discobot",
      label: "discourse_ai.discobot_discoveries.ask_ai",
      title: this.askTitle,
      active: this.askedActive,
      action: this.ask,
    };

    return { search, ask };
  }

  get allTopicsTitle() {
    return this.asksByDefault
      ? shortcutHint("shift", "enter")
      : shortcutHint("enter");
  }

  get askTitle() {
    return this.asksByDefault
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
    this.discobotDiscoveries.dismissDiscovery();
    this.args.clearTopicContext?.();
    this.args.searchTermChanged?.(this.query, {
      searchTopics: true,
      setPMInboxContext: true,
    });
  }

  @action
  searchThisTopic() {
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
        {{#each this.options key="kind" as |option|}}
          <DButton
            class="btn-default btn-small ai-discoveries-search-options__option --{{option.kind}}
              {{if option.active 'is-active'}}"
            @icon={{option.icon}}
            @label={{option.label}}
            @translatedLabel={{option.translatedLabel}}
            @translatedTitle={{option.title}}
            @action={{option.action}}
          />
        {{/each}}
        <DButton
          class="btn-default btn-small ai-discoveries-search-options__option --advanced"
          @icon="sliders"
          @translatedTitle={{this.advancedTitle}}
          @ariaLabel="search.open_advanced"
          @action={{@openAdvancedSearch}}
        />
      </div>
    {{/if}}
  </template>
}
