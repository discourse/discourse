import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";
import TopicStatusIcons from "discourse/helpers/topic-status-icons";
import { escapeExpression } from "discourse/lib/utilities";
import icon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class Status extends Component {
  @service currentUser;

  get canAct() {
    return this.currentUser && !this.args.disableActions;
  }

  get topicStatuses() {
    let topicStatuses = [];
    TopicStatusIcons.render(this.args.topicInfo, (name, key) => {
      const iconArgs = { class: key === "unpinned" ? "unpinned" : null };
      const statusIcon = { name, iconArgs };

      const attributes = {
        title: escapeExpression(i18n(`topic_statuses.${key}.help`)),
      };
      let klass = ["topic-status"];
      if (key === "unpinned" || key === "pinned") {
        klass.push("pin-toggle-button", key);
        klass = klass.join(" ");
      }
      topicStatuses.push({ attributes, klass, icon: statusIcon });
    });

    return topicStatuses;
  }

  @action
  togglePinnedForUser(e) {
    if (!this.canAct) {
      return;
    }
    const parent = e.target.closest(".topic-statuses");
    if (parent?.querySelector(".pin-toggle-button")?.contains(e.target)) {
      this.args.topicInfo.togglePinnedForUser();
    }
  }

  <template>
    <span class="topic-statuses">
      {{#each this.topicStatuses as |status|}}
        {{! template-lint-disable no-invalid-interactive }}
        <span
          class={{concatClass status.klass "topic-status"}}
          {{on "click" this.togglePinnedForUser}}
        >
          {{icon status.icon.name class=status.icon.iconArgs.class}}
        </span>
      {{/each}}
    </span>
  </template>
}
