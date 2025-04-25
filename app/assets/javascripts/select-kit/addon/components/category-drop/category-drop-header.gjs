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
import discourseComputed from "discourse/lib/decorators";
import ComboBoxSelectBoxHeaderComponent from "select-kit/components/combo-box/combo-box-header";

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
}
>>>>>>> a9ddbde3f6 (DEV: [gjs-codemod] renamed js to gjs)
