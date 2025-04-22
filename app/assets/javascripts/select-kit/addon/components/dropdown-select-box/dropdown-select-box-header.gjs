import { computed } from "@ember/object";
import { readOnly } from "@ember/object/computed";
import { classNameBindings, classNames } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import { resolveComponent } from "select-kit/components/select-kit";
import SingleSelectHeaderComponent from "select-kit/components/select-kit/single-select-header";

@classNames("dropdown-select-box-header")
@classNameBindings("btnClassName", "btnStyleClass", "btnCustomClasses")
export default class DropdownSelectBoxHeader extends SingleSelectHeaderComponent {
  @readOnly("selectKit.options.showFullTitle") showFullTitle;
  @readOnly("selectKit.options.customStyle") customStyle;
  @readOnly("selectKit.options.btnCustomClasses") btnCustomClasses;
  @readOnly("selectKit.options.caretUpIcon") caretUpIcon;
  @readOnly("selectKit.options.caretDownIcon") caretDownIcon;

  @computed("showFullTitle")
  get btnClassName() {
    return `btn ${this.showFullTitle ? "btn-icon-text" : "no-text btn-icon"}`;
  }

  @computed("customStyle")
  get btnStyleClass() {
    return `${this.customStyle ? "" : "btn-default"}`;
  }

  @computed("selectKit.isExpanded", "caretUpIcon", "caretDownIcon")
  get caretIcon() {
    return this.selectKit.isExpanded ? this.caretUpIcon : this.caretDownIcon;
  }

  <template>
    <div class="select-kit-header-wrapper">
      {{#each this.icons as |iconName|}} {{icon iconName}} {{/each}}

      {{#let
        (resolveComponent this this.selectKit.options.selectedNameComponent)
        as |SelectedNameComponent|
      }}
        <SelectedNameComponent
          @tabindex={{this.tabindex}}
          @item={{this.selectedContent}}
          @selectKit={{this.selectKit}}
          @shouldDisplayClearableButton={{this.shouldDisplayClearableButton}}
        />
      {{/let}}

      {{#if this.selectKit.options.showCaret}}
        {{icon this.caretIcon class="caret-icon"}}
      {{/if}}
      &#8203;
      {{! Zero-width space character, so icon-only button height = regular button height }}
    </div>
  </template>
}
