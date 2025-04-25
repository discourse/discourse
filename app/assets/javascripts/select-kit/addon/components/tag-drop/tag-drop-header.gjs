<<<<<<< HEAD
<<<<<<< HEAD
<div class="select-kit-header-wrapper">
  {{component
    this.selectKit.options.selectedNameComponent
    tabindex=this.tabindex
    item=this.selectedContent
    selectKit=this.selectKit
    shouldDisplayClearableButton=this.shouldDisplayClearableButton
  }}

  {{d-icon this.caretIcon class="caret-icon"}}
</div>
=======
import { classNames } from "@ember-decorators/component";
import ComboBoxSelectBoxHeaderComponent from "select-kit/components/combo-box/combo-box-header";

@classNames("tag-drop-header")
export default class TagDropHeader extends ComboBoxSelectBoxHeaderComponent {}
>>>>>>> a9ddbde3f6 (DEV: [gjs-codemod] renamed js to gjs)
=======
import { classNames } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import ComboBoxSelectBoxHeaderComponent from "select-kit/components/combo-box/combo-box-header";
import { resolveComponent } from "select-kit/components/select-kit";

@classNames("tag-drop-header")
export default class TagDropHeader extends ComboBoxSelectBoxHeaderComponent {
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
          @shouldDisplayClearableButton={{this.shouldDisplayClearableButton}}
        />
      {{/let}}

      {{icon this.caretIcon class="caret-icon"}}
    </div>
  </template>
}
>>>>>>> e41897a306 (DEV: [gjs-codemod] Convert final core components/routes to gjs)
