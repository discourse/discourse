<<<<<<< HEAD
<div class="select-kit-header-wrapper">
  {{component
    this.selectKit.options.selectedNameComponent
    tabindex=this.tabindex
    item=this.selectedContent
    selectKit=this.selectKit
    shouldDisplayIcon=this.shouldDisplayIcon
    shouldDisplayClearableButton=this.shouldDisplayClearableButton
  }}

  {{d-icon this.caretIcon class="caret-icon"}}
</div>
=======
import { reads } from "@ember/object/computed";
import { classNames } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import discourseComputed from "discourse/lib/decorators";
import ComboBoxSelectBoxHeaderComponent from "select-kit/components/combo-box/combo-box-header";
import { resolveComponent } from "select-kit/components/select-kit";

@classNames("category-drop-header")
export default class CategoryDropHeader extends ComboBoxSelectBoxHeaderComponent {
  @reads("selectKit.options.shouldDisplayIcon") shouldDisplayIcon;

  @discourseComputed("selectedContent.color")
  categoryBackgroundColor(categoryColor) {
    return categoryColor || "#e9e9e9";
  }

  @discourseComputed("selectedContent.text_color")
  categoryTextColor(categoryTextColor) {
    return categoryTextColor || "#333";
  }

  <template>
    <div class="select-kit-header-wrapper">
      {{#let
        (resolveComponent this this.selectKit.options.selectedNameComponent)
        as |SelectedNameComponent|
      }}
        <SelectedNameComponent
          @tabindex={{this.tabindex}}
          @item={{this.selectedContent}}
          @selectKit={{this.selectKit}}
          @shouldDisplayIcon={{this.shouldDisplayIcon}}
          @shouldDisplayClearableButton={{this.shouldDisplayClearableButton}}
        />
      {{/let}}

      {{icon this.caretIcon class="caret-icon"}}
    </div>
  </template>
}
<<<<<<< HEAD
>>>>>>> a9ddbde3f6 (DEV: [gjs-codemod] renamed js to gjs)
=======
>>>>>>> e41897a306 (DEV: [gjs-codemod] Convert final core components/routes to gjs)
