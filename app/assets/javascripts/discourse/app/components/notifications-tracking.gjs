import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { allLevels, buttonDetails } from "discourse/lib/notification-levels";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

function constructKey(prefix, level, suffix, key) {
  let string = prefix + "." + level;

  if (suffix) {
    string += suffix;
  }

  return i18n(string + "." + key);
}

class NotificationsTrackingTrigger extends Component {
  @service site;

  get showFullTitle() {
    return this.args.showFullTitle ?? true;
  }

  get showCaret() {
    return this.site.desktopView && (this.args.showCaret ?? true);
  }

  get title() {
    return constructKey(
      this.args.prefix,
      this.args.selectedLevel.key,
      this.args.suffix,
      "title"
    );
  }

  <template>
    {{icon @selectedLevel.icon}}

    {{#if this.showFullTitle}}
      <span class="d-button-label">
        {{this.title}}
      </span>
    {{/if}}

    {{#if this.showCaret}}
      {{icon "angle-down" class="notifications-tracking-btn__caret"}}
    {{/if}}
  </template>
}

export default class NotificationsTracking extends Component {
  @action
  registerDmenuApi(api) {
    this.dmenuApi = api;
  }

  @action
  async setNotificationLevel(level) {
    await this.dmenuApi.close({ focusTrigger: true });
    this.args.onChange?.(level);
  }

  @action
  description(level) {
    return constructKey(
      this.args.prefix,
      level.key,
      this.args.suffix,
      "description"
    );
  }

  @action
  label(level) {
    return constructKey(this.args.prefix, level.key, this.args.suffix, "title");
  }

  @action
  isSelectedClass(level) {
    return this.args.levelId === level.id ? "-selected" : "";
  }

  get selectedLevel() {
    return buttonDetails(this.args.levelId);
  }

  get levels() {
    return this.args.levels ?? allLevels;
  }

  <template>
    <DMenu
      @identifier="notifications-tracking"
      @modalForMobile={{true}}
      @triggerClass={{concatClass
        "notifications-tracking-trigger-btn"
        @triggerClass
      }}
      @onRegisterApi={{this.registerDmenuApi}}
      @title={{@title}}
      @autofocus={{false}}
      data-level-id={{this.selectedLevel.id}}
      data-level-name={{this.selectedLevel.key}}
      ...attributes
    >
      <:trigger>
        <NotificationsTrackingTrigger
          @showFullTitle={{@showFullTitle}}
          @showCaret={{@showCaret}}
          @selectedLevel={{this.selectedLevel}}
          @suffix={{@suffix}}
          @prefix={{@prefix}}
        />
      </:trigger>
      <:content>
        <DropdownMenu as |dropdown|>
          {{#each this.levels as |level|}}
            <dropdown.item>
              <DButton
                class={{concatClass
                  "notifications-tracking-btn"
                  (this.isSelectedClass level)
                }}
                @action={{fn this.setNotificationLevel level.id}}
                data-level-id={{level.id}}
                data-level-name={{level.key}}
              >
                <div class="notifications-tracking-btn__icons">
                  <PluginOutlet
                    @name="notifications-tracking-icons"
                    @outletArgs={{hash
                      selectedLevelId=@levelId
                      level=level
                      topic=@topic
                    }}
                  >
                    {{icon level.icon}}
                  </PluginOutlet>
                </div>
                <div class="notifications-tracking-btn__texts">
                  <span class="notifications-tracking-btn__label">
                    {{this.label level}}
                  </span>
                  <span class="notifications-tracking-btn__description">
                    {{this.description level}}
                  </span>
                </div>
              </DButton>
            </dropdown.item>
          {{/each}}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
