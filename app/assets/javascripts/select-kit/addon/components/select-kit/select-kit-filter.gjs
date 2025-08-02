import Component, { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { not } from "@ember/object/computed";
import { isPresent } from "@ember/utils";
import {
  attributeBindings,
  classNameBindings,
  classNames,
} from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import selectKitPropUtils from "select-kit/lib/select-kit-prop-utils";

@classNames("select-kit-filter")
@classNameBindings("isExpanded:is-expanded")
@attributeBindings("role")
@selectKitPropUtils
export default class SelectKitFilter extends Component {
  tabIndex = -1;

  @not("isHidden") isExpanded;

  @computed(
    "selectKit.options.{filterable,allowAny,autoFilterable}",
    "content.[]"
  )
  get isHidden() {
    return (
      !this.selectKit.options.filterable &&
      !this.selectKit.options.allowAny &&
      !this.selectKit.options.autoFilterable
    );
  }

  @discourseComputed(
    "selectKit.options.filterPlaceholder",
    "selectKit.options.translatedFilterPlaceholder",
    "selectKit.options.allowAny"
  )
  placeholder(placeholder, translatedPlaceholder) {
    if (isPresent(translatedPlaceholder)) {
      return translatedPlaceholder;
    }

    if (isPresent(placeholder)) {
      return i18n(placeholder);
    }

    return i18n(
      this.selectKit.options.allowAny
        ? "select_kit.filter_placeholder_with_any"
        : "select_kit.filter_placeholder"
    );
  }

  @action
  onPaste() {}

  @action
  onInput(event) {
    this.selectKit.onInput(event);
    return true;
  }

  @action
  onKeyup(event) {
    event.preventDefault();
    event.stopImmediatePropagation();
    return true;
  }

  @action
  onKeydown(event) {
    if (!this.selectKit.onKeydown(event)) {
      return false;
    }

    if (event.key === "Tab" && this.selectKit.isLoading) {
      this.selectKit.cancelSearch();
      this.selectKit.close(event);
      return true;
    }

    if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
      return true;
    }

    if (event.key === "Backspace" && !this.selectKit.filter) {
      this.selectKit.deselectLast();
      event.preventDefault();
      return false;
    }

    if (event.key === "ArrowUp") {
      this.selectKit.highlightLast();
      event.preventDefault();
      return false;
    }

    if (event.key === "ArrowDown") {
      if (!this.selectKit.isExpanded) {
        this.selectKit.open(event);
      }
      this.selectKit.highlightFirst();
      event.preventDefault();
      return false;
    }

    if (event.key === "Escape") {
      this.selectKit.close(event);
      this.selectKit.headerElement().focus();
      event.preventDefault();
      event.stopPropagation();
      return false;
    }

    if (event.key === "Enter" && this.selectKit.highlighted) {
      this.selectKit.select(
        this.getValue(this.selectKit.highlighted),
        this.selectKit.highlighted
      );
      event.preventDefault();
      event.stopImmediatePropagation();
      return false;
    }

    if (
      event.key === "Enter" &&
      (!this.selectKit.highlighted || this.selectKit.enterDisabled)
    ) {
      this.element.querySelector("input").focus();
      if (this.selectKit.enterDisabled) {
        event.preventDefault();
        event.stopImmediatePropagation();
      }
      return false;
    }

    this.selectKit.set("highlighted", null);
  }

  <template>
    {{#unless this.isHidden}}
      {{! filter-input-search prevents 1password from attempting autocomplete }}
      {{! template-lint-disable no-pointer-down-event-binding }}

      <Input
        tabindex={{0}}
        class="filter-input"
        placeholder={{this.placeholder}}
        autocomplete="off"
        autocorrect="off"
        autocapitalize="off"
        name="filter-input-search"
        spellcheck={{false}}
        @value={{readonly this.selectKit.filter}}
        @type="search"
        {{on "paste" this.onPaste}}
        {{on "keydown" this.onKeydown}}
        {{on "keyup" this.onKeyup}}
        {{on "input" this.onInput}}
      />

      {{#if this.selectKit.options.filterIcon}}
        {{icon this.selectKit.options.filterIcon class="filter-icon"}}
      {{/if}}
    {{/unless}}
  </template>
}
