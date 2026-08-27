import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import escapeRegExp from "discourse/lib/escape-regexp";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import shortcutLabel from "../lib/shortcut-label";

function shortcutHint(...keys) {
  return i18n("discourse_ai.discobot_discoveries.shortcut_hint", {
    shortcut: shortcutLabel(...keys),
  });
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

  // Only a user page narrows what a search would reach, by way of the operator
  // it puts in the term; category and tag pages still search globally.
  get userContext() {
    return this.search.searchContext?.type === "user"
      ? this.search.searchContext.user
      : null;
  }

  get inPMInbox() {
    return this.search.searchContext?.type === "private_messages";
  }

  get userPostsLabel() {
    return i18n("discourse_ai.discobot_discoveries.search_user_posts", {
      username: this.userContext?.username,
    });
  }

  get userOperator() {
    const username = this.userContext?.username;
    return username ? `@${username}` : null;
  }

  // Read off the term rather than remembered: the operator is visible in the
  // input, so it stays recognised however it got there — picked here, typed by
  // hand, or carried in from an earlier search.
  get termNarrowedToUser() {
    if (!this.userOperator) {
      return false;
    }

    const operator = escapeRegExp(this.userOperator);
    return new RegExp(`(?:^|\\s)${operator}(?=\\s|$)`, "i").test(
      this.query || ""
    );
  }

  get userPostsActive() {
    return this.termNarrowedToUser;
  }

  get termWithoutUser() {
    const operator = escapeRegExp(this.userOperator);

    return (this.query || "")
      .replace(new RegExp(`(?:^|\\s)${operator}(?=\\s|$)`, "gi"), " ")
      .replace(/\s+/g, " ")
      .trim();
  }

  // The inbox scope lives on the menu rather than in the term, so this reads the
  // menu's own state — which is already on for a fresh search from an inbox.
  get messagesActive() {
    return Boolean(this.args.inPMInboxContext);
  }

  // Compared against the term it was chosen for: a changed term has to be
  // resubmitted, so the option that answered the old one stops reading as active

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
      this.userPostsActive ||
      this.messagesActive
    ) {
      return false;
    }

    return Boolean(this.args.searchTopics);
  }

  // Only the options that have one: scope has never had a keybinding, so the
  // three that map to enter, shift+enter and ctrl/cmd+enter say so and the rest
  // stay quiet rather than inventing hints.
  get allTopicsTitle() {
    return shortcutHint("enter");
  }

  get askTitle() {
    return shortcutHint("shift", "enter");
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
    if (this.termNarrowedToUser) {
      this.args.searchTermChanged?.(this.termWithoutUser, {
        searchTopics: true,
      });
      return;
    }

    this.args.updateTypeFilter?.(null);
    this.args.triggerSearch?.();
  }

  @action
  searchUserPosts() {
    this.discobotDiscoveries.dismissDiscovery();
    this.args.clearTopicContext?.();
    this.args.clearPMInboxContext?.();
    // mirrors the native shortcut: the operator goes in the term, but only once
    const term = this.termNarrowedToUser
      ? this.query
      : `${this.query} ${this.userOperator}`;

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
    // asking never honours a scope, so picking it leaves any behind
    this.args.clearTopicContext?.();
    this.args.clearPMInboxContext?.();
    this.discobotDiscoveries.triggerDiscovery(this.query);
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
        {{#if this.userContext}}
          <DButton
            class="btn-default btn-small ai-discoveries-search-options__option --user
              {{if this.userPostsActive 'is-active'}}"
            @icon="magnifying-glass"
            @translatedLabel={{this.userPostsLabel}}
            @action={{this.searchUserPosts}}
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
