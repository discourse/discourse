import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { computed } from "@ember/object";
import {
  attributeBindings,
  classNames,
  tagName,
} from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import FormatSelectedContent from "discourse/select-kit/components/multi-select/format-selected-content";
import { resolveComponent } from "discourse/select-kit/components/select-kit";
import SelectKitHeaderComponent from "discourse/select-kit/components/select-kit/select-kit-header";
import { or } from "discourse/truth-helpers";

@tagName("summary")
@classNames("multi-select-header")
@attributeBindings("ariaLabel:aria-label")
export default class MultiSelectHeader extends SelectKitHeaderComponent {
  @tracked _caretUpIconOverride;
  @tracked _caretDownIconOverride;
  @tracked _ariaLabelOverride;

  @computed("selectKit.options.caretUpIcon")
  get caretUpIcon() {
    if (this._caretUpIconOverride !== undefined) {
      return this._caretUpIconOverride;
    }
    return this.selectKit?.options?.caretUpIcon;
  }

  set caretUpIcon(value) {
    this._caretUpIconOverride = value;
  }

  @computed("selectKit.options.caretDownIcon")
  get caretDownIcon() {
    if (this._caretDownIconOverride !== undefined) {
      return this._caretDownIconOverride;
    }
    return this.selectKit?.options?.caretDownIcon;
  }

  set caretDownIcon(value) {
    this._caretDownIconOverride = value;
  }

  @computed("selectKit.options.headerAriaLabel")
  get ariaLabel() {
    if (this._ariaLabelOverride !== undefined) {
      return this._ariaLabelOverride;
    }
    return this.selectKit?.options?.headerAriaLabel;
  }

  set ariaLabel(value) {
    this._ariaLabelOverride = value;
  }

  @computed("selectKit.isExpanded", "caretUpIcon", "caretDownIcon")
  get caretIcon() {
    return this.selectKit.isExpanded ? this.caretUpIcon : this.caretDownIcon;
  }

  <template>
    <div class="select-kit-header-wrapper">
      {{#each this.icons as |iconName|}}
        {{icon iconName}}
      {{/each}}

      {{#if this.selectKit.options.useHeaderFilter}}
        <div class="select-kit-header--filter">
          {{#if this.selectedContent.length}}
            {{#let
              (resolveComponent
                this this.selectKit.options.selectedChoiceComponent
              )
              as |SelectedChoiceComponent|
            }}
              {{#each this.selectedContent as |item|}}
                <SelectedChoiceComponent
                  @selectKit={{this.selectKit}}
                  @item={{item}}
                />
              {{/each}}
            {{/let}}
          {{/if}}

          {{#let
            (resolveComponent this this.selectKit.options.filterComponent)
            as |FilterComponent|
          }}
            <FilterComponent
              @selectKit={{this.selectKit}}
              @id={{concat this.selectKit.uniqueID "-filter"}}
              @hidePlaceholderWithSelection={{true}}
            />
          {{/let}}
        </div>
      {{else}}
        <FormatSelectedContent
          @content={{or this.selectedContent this.selectKit.noneItem}}
          @selectKit={{this.selectKit}}
        />
        {{#if this.caretIcon}}
          {{icon this.caretIcon class="angle-icon"}}
        {{/if}}
      {{/if}}
    </div>
  </template>
}
