import { computed } from "@ember/object";
import { or } from "@ember/object/computed";
import {
  attributeBindings,
  classNames,
  tagName,
} from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { resolveComponent } from "select-kit/components/select-kit";
import SelectKitHeaderComponent from "select-kit/components/select-kit/select-kit-header";

@tagName("summary")
@classNames("single-select-header")
@attributeBindings("name", "ariaLabel:aria-label")
export default class SingleSelectHeader extends SelectKitHeaderComponent {
  @or("selectKit.options.headerAriaLabel", "name") ariaLabel;

  focusIn(event) {
    event.stopImmediatePropagation();

    document.querySelectorAll(".select-kit-header").forEach((header) => {
      if (header !== event.target) {
        header.parentNode.open = false;
      }
    });
  }

  @computed("selectedContent.name")
  get name() {
    if (this.selectedContent) {
      return i18n("select_kit.filter_by", {
        name: this.getName(this.selectedContent),
      });
    } else {
      return i18n("select_kit.select_to_filter");
    }
  }

  <template>
    <div class="select-kit-header-wrapper">
      {{#each this.icons as |iconName|}} {{icon iconName}} {{/each}}

      {{#let
        (resolveComponent this this.selectKit.options.selectedNameComponent)
        as |SelectedNameComponent|
      }}
        <SelectedNameComponent
          @item={{this.selectedContent}}
          @selectKit={{this.selectKit}}
        />
      {{/let}}
    </div>
  </template>
}
