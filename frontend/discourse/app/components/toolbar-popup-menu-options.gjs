import Component from "@glimmer/component";
import { array, concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import DMenu from "discourse/float-kit/components/d-menu";
import { formatShortcut } from "discourse/lib/shortcut-format";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DShortcut from "discourse/ui-kit/d-shortcut";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ToolbarPopupMenuOptions extends Component {
  @service capabilities;

  trackScrollability = modifier((element) => {
    const innerContent = element.closest(".fk-d-menu__inner-content");
    const menuElement = innerContent?.parentElement;
    if (!innerContent || !menuElement) {
      return;
    }

    const checkScroll = () => {
      const { scrollHeight, scrollTop, clientHeight } = innerContent;
      const hasOverflow = scrollHeight > clientHeight;
      menuElement.classList.toggle(
        "--scroll-top",
        hasOverflow && scrollTop > 2
      );
      menuElement.classList.toggle(
        "--scroll-bottom",
        hasOverflow && scrollHeight - scrollTop - clientHeight > 2
      );
    };

    const observer = new ResizeObserver(checkScroll);
    observer.observe(innerContent);
    innerContent.addEventListener("scroll", checkScroll, { passive: true });
    checkScroll();

    return () => {
      observer.disconnect();
      innerContent.removeEventListener("scroll", checkScroll);
    };
  });

  willDestroy() {
    super.willDestroy();
    this.dMenu?.destroy();
  }

  get convertedContent() {
    return this.args.content
      .map(this.#convertMenuOption.bind(this))
      .filter(Boolean);
  }

  get textManipulationState() {
    return this.args.context?.textManipulation?.state;
  }

  get triggerLabel() {
    const label = this.args.triggerLabel;
    if (typeof label === "function") {
      return label({ state: this.textManipulationState });
    }

    return label;
  }

  @action
  async onSelect(option) {
    await this.dMenu?.close();
    this.args.onChange?.(option);
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  getActive(option) {
    return option.active?.({ state: this.textManipulationState });
  }

  @action
  getIcon(config) {
    if (typeof config.icon === "function") {
      return config.icon?.({ state: this.textManipulationState });
    }

    return config.icon;
  }

  #convertMenuOption(content) {
    if (content.condition !== false) {
      const shortcutKeys = content.shortcut
        ? `mod+${content.shortcut}`
        : undefined;
      const labelText = this.#calculateLabelText(content);
      const title = this.#calculateTitle(content, labelText, shortcutKeys);

      return Object.defineProperties(
        {},
        Object.getOwnPropertyDescriptors({
          ...content,
          labelText,
          title,
          shortcutKeys,
        })
      );
    }
  }

  #calculateLabelText(content) {
    if (!content.label && !content.translatedLabel) {
      return;
    }

    return content.translatedLabel
      ? content.translatedLabel
      : i18n(content.label);
  }

  /**
   * A labelled row draws its shortcut, so its title carries none; an
   * icon-only row has nowhere else to show it.
   */
  #calculateTitle(content, labelText, shortcutKeys) {
    const title = content.translatedTitle
      ? content.translatedTitle
      : content.title
        ? i18n(content.title)
        : labelText;

    if (labelText || !shortcutKeys || !this.capabilities.hasKeyboard) {
      return title;
    }
    return `${title} (${formatShortcut(shortcutKeys).label})`;
  }

  <template>
    <DMenu
      tabindex="-1"
      title={{@title}}
      @class="toolbar-popup-menu-options"
      @fallbackPlacements={{array "top"}}
      @groupIdentifier="toolbar-menu"
      @identifier={{concat "toolbar-menu__" @class}}
      @modalForMobile={{true}}
      @offset={{5}}
      @onKeydown={{@onKeydown}}
      @onRegisterApi={{this.onRegisterApi}}
      @onShow={{@onOpen}}
      @placement="bottom"
      @triggerClass={{dConcatClass "toolbar__button" @class}}
    >
      <:trigger>
        {{dIcon (this.getIcon this.args)}}
        {{#if this.triggerLabel}}
          <span class="toolbar-popup-menu-options__trigger-label">
            {{this.triggerLabel}}
          </span>
        {{/if}}
      </:trigger>
      <:content>
        <DDropdownMenu {{this.trackScrollability}} as |dropdown|>
          {{#if @header}}
            <li class="dropdown-menu__header">{{@header}}</li>
          {{/if}}
          {{#each this.convertedContent as |option|}}
            <dropdown.item>
              <DShortcut @keys={{option.shortcutKeys}} as |shortcut|>
                <DButton
                  aria-keyshortcuts={{shortcut.aria}}
                  class={{dConcatClass (if (this.getActive option) "--active")}}
                  data-name={{option.name}}
                  @action={{fn this.onSelect option}}
                  @icon={{this.getIcon option}}
                  @translatedTitle={{option.title}}
                >
                  {{#if option.labelText}}
                    <span class="d-button-label">
                      <span class="d-button-label__text">
                        {{option.labelText}}
                      </span>
                      <shortcut.Kbd
                        class={{dConcatClass
                          "shortcut"
                          (if option.alwaysShowShortcut "--always-visible")
                        }}
                      />
                      {{#if option.showActiveIcon}}
                        {{dIcon "check" class="d-button-label__active-icon"}}
                      {{/if}}
                    </span>
                  {{/if}}
                </DButton>
              </DShortcut>
            </dropdown.item>
          {{/each}}
        </DDropdownMenu>
      </:content>
    </DMenu>
  </template>
}
