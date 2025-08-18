import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

const UNPINNED = "unpinned";
const PINNED = "pinned";
const GLOBALLY = "_globally";

class PinnedOptionsTrigger extends Component {
  @service site;

  get showFullTitle() {
    return this.args.showFullTitle ?? true;
  }

  get showCaret() {
    return this.site.desktopView && (this.args.showCaret ?? true);
  }

  get pinnedKey() {
    if (!this.args.value) {
      return UNPINNED;
    }

    if (this.args.topic?.pinned_globally) {
      return `${PINNED}${GLOBALLY}`;
    }

    return PINNED;
  }

  get title() {
    return i18n(`topic_statuses.${this.pinnedKey}.title`);
  }

  get iconName() {
    return this.pinnedKey === UNPINNED ? "thumbtack unpinned" : "thumbtack";
  }

  <template>
    <button
      class={{concatClass
        "btn btn-default"
        (if this.showFullTitle "btn-icon-text" "no-text")
      }}
      ...attributes
    >
      {{icon this.iconName}}

      {{#if this.showFullTitle}}
        <span class="d-button-label">
          {{this.title}}
        </span>
      {{/if}}

      {{#if this.showCaret}}
        {{icon "angle-down" class="pinned-options-btn__caret"}}
      {{/if}}
    </button>
  </template>
}

export default class PinnedOptions extends Component {
  @action
  registerDmenuApi(api) {
    this.dmenuApi = api;
  }

  @action
  async setPinnedState(value) {
    await this.dmenuApi.close({ focusTrigger: true });

    const topic = this.args.topic;
    if (value === UNPINNED) {
      await topic.clearPin();
    } else {
      await topic.rePin();
    }
  }

  @action
  isSelectedClass(optionId) {
    const currentValue = this.args.value ? PINNED : UNPINNED;
    return currentValue === optionId ? "-selected" : "";
  }

  get options() {
    const globally = this.args.topic?.pinned_globally ? GLOBALLY : "";

    return [
      {
        id: PINNED,
        title: i18n(`topic_statuses.pinned${globally}.title`),
        description: i18n(`topic_statuses.pinned${globally}.help`),
        icon: "thumbtack",
      },
      {
        id: UNPINNED,
        title: i18n("topic_statuses.unpinned.title"),
        description: i18n("topic_statuses.unpinned.help"),
        icon: "thumbtack unpinned",
      },
    ];
  }

  <template>
    <DMenu
      @identifier="pinned-options"
      @modalForMobile={{true}}
      @triggerClass={{concatClass
        "btn-default"
        "pinned-options-trigger-btn"
        @triggerClass
      }}
      @contentClass={{@contentClass}}
      @onRegisterApi={{this.registerDmenuApi}}
      @autofocus={{false}}
      @triggerComponent={{component
        PinnedOptionsTrigger
        showFullTitle=@showFullTitle
        showCaret=@showCaret
        value=@value
        topic=@topic
      }}
      ...attributes
    >
      <:content>
        <DropdownMenu as |dropdown|>
          {{#each this.options as |option|}}
            <dropdown.item>
              <DButton
                class={{concatClass
                  "pinned-options-btn"
                  (this.isSelectedClass option.id)
                }}
                @action={{fn this.setPinnedState option.id}}
                data-pinned-state={{option.id}}
              >
                <div class="pinned-options-btn__icons">
                  {{icon option.icon}}
                </div>
                <div class="pinned-options-btn__texts">
                  <span class="pinned-options-btn__label">
                    {{option.title}}
                  </span>
                  {{#if option.description}}
                    <span class="pinned-options-btn__description">
                      {{option.description}}
                    </span>
                  {{/if}}
                </div>
              </DButton>
            </dropdown.item>
          {{/each}}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
