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
        {{~#if this.canAct~}}
          <a
            class="topic-status --bookmarked"
            href={{@topic.url}}
            title={{i18n "topic_statuses.bookmarked.help"}}
          >{{dIcon "bookmark"}}</a>
        {{~else~}}
          <span
            class="topic-status --bookmarked"
            title={{i18n "topic_statuses.bookmarked.help"}}
          >{{dIcon "bookmark"}}</span>
        {{~/if~}}
      {{~/if~}}

      {{~#if (and @topic.closed @topic.archived)~}}
        <span
          class="topic-status --closed --archived"
          title={{i18n "topic_statuses.locked_and_archived.help"}}
        >{{dIcon "topic.closed"}}</span>
      {{~else if @topic.closed~}}
        <span
          class="topic-status --closed"
          title={{i18n "topic_statuses.locked.help"}}
        >{{dIcon "topic.closed"}}</span>
      {{~else if @topic.archived~}}
        <span
          class="topic-status --archived"
          title={{i18n "topic_statuses.archived.help"}}
        >{{dIcon "topic.closed"}}</span>
      {{~/if~}}

      {{~#if @topic.is_warning~}}
        <span
          class="topic-status --warning topic-status-warning"
          title={{i18n "topic_statuses.warning.help"}}
        >{{dIcon "envelope"}}</span>
      {{~else if (and @showPrivateMessageIcon @topic.isPrivateMessage)~}}
        <span
          class="topic-status --personal-message"
          title={{i18n "topic_statuses.personal_message.help"}}
        >{{dIcon "envelope"}}</span>
      {{~/if~}}

      {{~#if @topic.pinned~}}
        {{~#if this.canAct~}}
          <a
            class="topic-status --pinned pin-toggle-button"
            href
            title={{i18n "topic_statuses.pinned.help"}}
            {{on "click" this.togglePinned}}
          >{{dIcon "thumbtack"}}</a>
        {{~else~}}
          <span
            class="topic-status --pinned"
            title={{i18n "topic_statuses.pinned.help"}}
          >{{dIcon "thumbtack"}}</span>
        {{~/if~}}
      {{~else if @topic.unpinned~}}
        {{~#if this.canAct~}}
          <a
            class="topic-status --unpinned pin-toggle-button"
            href
            title={{i18n "topic_statuses.unpinned.help"}}
            {{on "click" this.togglePinned}}
          >{{dIcon "thumbtack" class="unpinned"}}</a>
        {{~else~}}
          <span
            class="topic-status --unpinned"
            title={{i18n "topic_statuses.unpinned.help"}}
          >{{dIcon "thumbtack" class="unpinned"}}</span>
        {{~/if~}}
      {{~/if~}}

      {{~#if @topic.invisible~}}
        <span
          class="topic-status --invisible"
          title={{i18n
            "topic_statuses.unlisted.help"
            unlistedReason=@topic.visibilityReasonTranslated
          }}
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
