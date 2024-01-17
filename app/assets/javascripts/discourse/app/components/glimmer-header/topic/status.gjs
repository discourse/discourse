import Component from "@glimmer/component";
import { iconNode } from "discourse-common/lib/icon-library";
import TopicStatusIcons from "discourse/helpers/topic-status-icons";
import { escapeExpression } from "discourse/lib/utilities";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import I18n from "discourse-i18n";
import icon from "discourse-common/helpers/d-icon";

export default class Status extends Component {
  @service currentUser;

  get canAct() {
    return this.currentUser && !this.args.disableActions;
  }

  get topicStatuses() {
    let topicStatuses = [];
    TopicStatusIcons.render(this.args.topic, (name, key) => {
      const iconArgs = { class: key === "unpinned" ? "unpinned" : null };
      const icon = { name, iconArgs };

      const attributes = {
        title: escapeExpression(I18n.t(`topic_statuses.${key}.help`)),
      };
      let klass = "topic-status";
      if (key === "unpinned" || key === "pinned") {
        klass += `.pin-toggle-button.${key}`;
      }
      topicStatuses.push({ attributes, icon, klass });
    });

    return topicStatuses;
  }

  @action
  togglePinnedForUser(e) {
    const parent = e.target.closest(".topic-statuses");
    if (parent?.querySelector(".pin-toggle-button")?.contains(e.target)) {
      this.attrs.topic.togglePinnedForUser();
    }
  }

  <template>
    <span class="topic-statuses" {{on "click" this.togglePinnedForUser}}>
      {{#each this.topicStatuses as |status|}}
        {{#if this.canAct}}
          <a class="topic-status {{status.klass}}">
            {{icon status.icon.name class=status.icon.iconArgs.class}}
          </a>
        {{else}}
          <span class="topic-status {{status.klass}}">
            {{icon status.icon.name class=status.icon.iconArgs.class}}
          </span>
        {{/if}}
      {{/each}}
    </span>
  </template>
}
