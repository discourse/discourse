import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { and } from "discourse/truth-helpers";
import dElement from "discourse/ui-kit/helpers/d-element";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class TopicStatus extends Component {
  @service currentUser;

  get wrapperElement() {
    return dElement(this.args.tagName ?? "span");
  }

  get canAct() {
    // TODO: @disableActions -> !@interactive
    return this.currentUser && !this.args.disableActions;
  }

  @action
  togglePinned(e) {
    e.preventDefault();
    this.args.topic.togglePinnedForUser();
  }

  <template>
    {{~! no whitespace ~}}
    <this.wrapperElement class="topic-statuses">
      {{~#if @topic.bookmarked~}}
        <a
          href={{@topic.url}}
          title={{i18n "topic_statuses.bookmarked.help"}}
          class="topic-status --bookmarked"
        >{{dIcon "bookmark"}}</a>
      {{~/if~}}

      {{~#if (and @topic.closed @topic.archived)~}}
        <span
          title={{i18n "topic_statuses.locked_and_archived.help"}}
          class="topic-status --closed --archived"
        >{{dIcon "topic.closed"}}</span>
      {{~else if @topic.closed~}}
        <span
          title={{i18n "topic_statuses.locked.help"}}
          class="topic-status --closed"
        >{{dIcon "topic.closed"}}</span>
      {{~else if @topic.archived~}}
        <span
          title={{i18n "topic_statuses.archived.help"}}
          class="topic-status --archived"
        >{{dIcon "topic.closed"}}</span>
      {{~/if~}}

      {{~#if @topic.is_warning~}}
        <span
          title={{i18n "topic_statuses.warning.help"}}
          class="topic-status --warning topic-status-warning"
        >{{dIcon "envelope"}}</span>
      {{~else if (and @showPrivateMessageIcon @topic.isPrivateMessage)~}}
        <span
          title={{i18n "topic_statuses.personal_message.help"}}
          class="topic-status --personal-message"
        >{{dIcon "envelope"}}</span>
      {{~/if~}}

      {{~#if @topic.pinned~}}
        {{~#if this.canAct~}}
          <a
            {{on "click" this.togglePinned}}
            href
            title={{i18n "topic_statuses.pinned.help"}}
            class="topic-status --pinned pin-toggle-button"
          >{{dIcon "thumbtack"}}</a>
        {{~else~}}
          <span
            title={{i18n "topic_statuses.pinned.help"}}
            class="topic-status --pinned"
          >{{dIcon "thumbtack"}}</span>
        {{~/if~}}
      {{~else if @topic.unpinned~}}
        {{~#if this.canAct~}}
          <a
            {{on "click" this.togglePinned}}
            href
            title={{i18n "topic_statuses.unpinned.help"}}
            class="topic-status --unpinned pin-toggle-button"
          >{{dIcon "thumbtack" class="unpinned"}}</a>
        {{~else~}}
          <span
            title={{i18n "topic_statuses.unpinned.help"}}
            class="topic-status --unpinned"
          >{{dIcon "thumbtack" class="unpinned"}}</span>
        {{~/if~}}
      {{~/if~}}

      {{~#if @topic.invisible~}}
        <span
          title={{i18n
            "topic_statuses.unlisted.help"
            unlistedReason=@topic.visibilityReasonTranslated
          }}
          class="topic-status --invisible"
        >{{dIcon "far-eye-slash"}}</span>
      {{~/if~}}
      <PluginOutlet
        @name="after-topic-status"
        @outletArgs={{lazyHash topic=@topic context=@context}}
      />
      {{~! no whitespace ~}}
    </this.wrapperElement>
    {{~! no whitespace ~}}
  </template>
}
