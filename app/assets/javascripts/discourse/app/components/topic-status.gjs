import Component from "@glimmer/component";
import { concat, get, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { and } from "truth-helpers";
import PluginOutlet from "discourse/components/plugin-outlet";
import element from "discourse/helpers/element";
import TopicStatusIcons from "discourse/helpers/topic-status-icons";
import icon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class TopicStatus extends Component {
  @service currentUser;

  get canAct() {
    // TODO: @disableActions -> !@interactive
    return this.currentUser && !this.args.disableActions;
  }

  @action
  togglePinned(e) {
    e.preventDefault();
    this.args.topic.togglePinnedForUser();
  }

  get wrapperElement() {
    return element(this.args.tagName ?? "span");
  }

  <template>
    {{~! no whitespace ~}}
    <this.wrapperElement class="topic-statuses">
      {{~#if (and @topic.closed @topic.archived)~}}
        <span
          title={{i18n "topic_statuses.locked_and_archived.help"}}
          class="topic-status"
        >{{icon "lock"}}</span>
      {{~else if @topic.closed~}}
        <span
          title={{i18n "topic_statuses.locked.help"}}
          class="topic-status"
        >{{icon "lock"}}</span>
      {{~else if @topic.archived~}}
        <span
          title={{i18n "topic_statuses.archived.help"}}
          class="topic-status"
        >{{icon "lock"}}</span>
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

      {{~#each TopicStatusIcons.entries as |entry|~}}
        {{~#if (get @topic entry.attribute)~}}
          <span
            title={{i18n (concat "topic_statuses." entry.titleKey "help")}}
            class="topic-status"
          >{{icon entry.iconName}}</span>
        {{~/if~}}
      {{~/each~}}

      <PluginOutlet
        @name="after-topic-status"
        @outletArgs={{hash topic=@topic}}
      />
      {{~! no whitespace ~}}
    </this.wrapperElement>
    {{~! no whitespace ~}}
  </template>
}
