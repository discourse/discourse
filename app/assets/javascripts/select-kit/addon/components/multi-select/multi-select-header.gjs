import { concat } from "@ember/helper";
import { computed } from "@ember/object";
import { reads } from "@ember/object/computed";
import {
  attributeBindings,
  classNames,
  tagName,
} from "@ember-decorators/component";
import { or } from "truth-helpers";
import icon from "discourse/helpers/d-icon";
import FormatSelectedContent from "select-kit/components/multi-select/format-selected-content";
import { resolveComponent } from "select-kit/components/select-kit";
import SelectKitHeaderComponent from "select-kit/components/select-kit/select-kit-header";

@tagName("summary")
@classNames("multi-select-header")
@attributeBindings("ariaLabel:aria-label")
export default class MultiSelectHeader extends SelectKitHeaderComponent {
  @reads("selectKit.options.caretUpIcon") caretUpIcon;
  @reads("selectKit.options.caretDownIcon") caretDownIcon;
  @reads("selectKit.options.headerAriaLabel") ariaLabel;

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

        {{icon this.caretIcon class="caret-icon"}}
      {{/if}}
    </div>
  </template>
}
