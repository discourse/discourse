import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { and } from "truth-helpers";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import element from "discourse/helpers/element";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

export default class TopicStatus extends Component {
  @service currentUser;

  get wrapperElement() {
    return element(this.args.tagName ?? "span");
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
          class="topic-status"
        >{{icon "bookmark"}}</a>
      {{~/if~}}

      {{~#if (and @topic.closed @topic.archived)~}}
        <span
          title={{i18n "topic_statuses.locked_and_archived.help"}}
          class="topic-status"
        >{{icon "topic.closed"}}</span>
      {{~else if @topic.closed~}}
        <span
          title={{i18n "topic_statuses.locked.help"}}
          class="topic-status"
        >{{icon "topic.closed"}}</span>
      {{~else if @topic.archived~}}
        <span
          title={{i18n "topic_statuses.archived.help"}}
          class="topic-status"
        >{{icon "topic.closed"}}</span>
      {{~/if~}}

      {{~#if @topic.is_warning~}}
        <span
          title={{i18n "topic_statuses.warning.help"}}
          class="topic-status topic-status-warning"
        >{{icon "envelope"}}</span>
      {{~else if (and @showPrivateMessageIcon @topic.isPrivateMessage)~}}
        <span
          title={{i18n "topic_statuses.personal_message.help"}}
          class="topic-status"
        >{{icon "envelope"}}</span>
      {{~/if~}}

      {{~#if @topic.pinned~}}
        {{~#if this.canAct~}}
          <a
            {{on "click" this.togglePinned}}
            href
            title={{i18n "topic_statuses.pinned.help"}}
            class="topic-status pinned pin-toggle-button"
          >{{icon "thumbtack"}}</a>
        {{~else~}}
          <span
            title={{i18n "topic_statuses.pinned.help"}}
            class="topic-status pinned"
          >{{icon "thumbtack"}}</span>
        {{~/if~}}
      {{~else if @topic.unpinned~}}
        {{~#if this.canAct~}}
          <a
            {{on "click" this.togglePinned}}
            href
            title={{i18n "topic_statuses.unpinned.help"}}
            class="topic-status unpinned pin-toggle-button"
          >{{icon "thumbtack" class="unpinned"}}</a>
        {{~else~}}
          <span
            title={{i18n "topic_statuses.unpinned.help"}}
            class="topic-status unpinned"
          >{{icon "thumbtack" class="unpinned"}}</span>
        {{~/if~}}
      {{~/if~}}

      {{~#if @topic.invisible~}}
        <span
          title={{i18n
            "topic_statuses.unlisted.help"
            unlistedReason=@topic.visibilityReasonTranslated
          }}
          class="topic-status"
        >{{icon "far-eye-slash"}}</span>
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
