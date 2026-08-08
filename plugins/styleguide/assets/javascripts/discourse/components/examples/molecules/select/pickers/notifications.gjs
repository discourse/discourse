import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { notificationLevels } from "../../../../../lib/select-fixtures";

export default class NotificationsSelectExample extends Component {
  @tracked actionCount = 0;
  @tracked value = "watching";

  get event() {
    if (this.actionCount > 0) {
      return i18n(
        "styleguide.sections.select.pickers.notifications.action_count",
        { count: this.actionCount }
      );
    }

    return i18n("styleguide.sections.select.pickers.notifications.event_idle");
  }

  get items() {
    return notificationLevels(this.manage);
  }

  @action
  manage() {
    this.actionCount++;
  }

  @action
  update(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-notifications"
      @placement="top-start"
      @items={{this.items}}
      @value={{this.value}}
      @onChange={{this.update}}
      @variant="static"
      @valueField="level"
      @labelField="title"
    >
      <:selection as |level|>
        <span class="select-examples__row select-examples__row--glyph">
          {{dIcon level.icon}}
          {{level.title}}
        </span>
      </:selection>

      <:item as |level|>
        <span class="select-examples__row select-examples__row--identity">
          {{dIcon level.icon}}
          <span class="select-examples__details">
            <span class="select-examples__primary">{{level.title}}</span>
            <span class="select-examples__secondary">
              {{level.description}}
            </span>
          </span>
        </span>
      </:item>
    </DSelect>

    <output
      class="styleguide-example__result"
      data-test-notification-event
    >{{this.event}}</output>
  </template>
}
