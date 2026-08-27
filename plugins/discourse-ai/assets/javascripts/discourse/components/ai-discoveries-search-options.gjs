import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import escapeRegExp from "discourse/lib/escape-regexp";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

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

  // The configured or most recently selected mode applies when the term is submitted.
  get askedActive() {
    return Boolean(this.query) && this.discobotDiscoveries.mode === "ask";
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

    return this.discobotDiscoveries.mode === "search";
  }

  @action
  searchAllTopics() {
    this.discobotDiscoveries.setMode("search");
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
    this.discobotDiscoveries.setMode("search");
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
    this.discobotDiscoveries.setMode("search");
    this.discobotDiscoveries.dismissDiscovery();
    this.args.clearTopicContext?.();
    this.args.searchTermChanged?.(this.query, {
      searchTopics: true,
      setPMInboxContext: true,
    });
  }

  @action
  searchThisTopic() {
    this.discobotDiscoveries.setMode("search");
    this.scopedTerm = this.query;
    this.discobotDiscoveries.dismissDiscovery();
    this.args.searchTermChanged?.(this.query, {
      searchTopics: true,
      setTopicContext: true,
    });
  }

  @action
  ask() {
    this.discobotDiscoveries.setMode("ask");
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
        <DButton
          class="btn-default btn-small ai-discoveries-search-options__option --search
            {{if this.allTopicsActive 'is-active'}}"
          @icon="magnifying-glass"
          @label="discourse_ai.discobot_discoveries.search_all_topics"
          @action={{this.searchAllTopics}}
        />
        <DButton
          class="btn-default btn-small ai-discoveries-search-options__option --ask
            {{if this.askedActive 'is-active'}}"
          @icon="far-discobot"
          @label="discourse_ai.discobot_discoveries.ask_ai"
          @action={{this.ask}}
        />
        {{#if this.allTopicsActive}}
          <DButton
            class="btn-default btn-small ai-discoveries-search-options__option --advanced"
            @icon="sliders"
            @title="search.open_advanced"
            @ariaLabel="search.open_advanced"
            @action={{@openAdvancedSearch}}
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
