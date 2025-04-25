<<<<<<< HEAD
{{#unless this.selectKit.isHidden}}
  {{component
    this.selectKit.options.headerComponent
    tabindex=this.tabindex
    value=this.value
    selectedContent=this.selectedContent
    selectKit=this.selectKit
    id=(concat this.selectKit.uniqueID "-header")
  }}

  <SelectKit::SelectKitBody
    @selectKit={{this.selectKit}}
    @id={{concat this.selectKit.uniqueID "-body"}}
  >
    {{component
      this.selectKit.options.filterComponent
      selectKit=this.selectKit
      id=(concat this.selectKit.uniqueID "-filter")
    }}

    {{#each this.collections as |collection|}}
      {{component
        (component-for-collection collection.identifier this.selectKit)
        collection=collection
        selectKit=this.selectKit
        value=this.value
      }}
    {{/each}}

    {{#if this.selectKit.filter}}
      {{#if (and this.selectKit.hasNoContent (not this.selectKit.isLoading))}}
        <span class="no-content" role="alert">
          {{i18n "select_kit.no_content"}}
        </span>
      {{else}}
        <span class="results-count" role="alert">
          {{i18n "select_kit.results_count" count=this.mainCollection.length}}
        </span>
      {{/if}}
    {{/if}}

  </SelectKit::SelectKitBody>
{{/unless}}
=======
import { computed } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { classNames } from "@ember-decorators/component";
import SelectKitComponent, {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

@classNames("single-select")
@selectKitOptions({
  headerComponent: "select-kit/single-select-header",
})
@pluginApiIdentifiers(["single-select"])
export default class SingleSelect extends SelectKitComponent {
  singleSelect = true;

  @computed("value", "content.[]", "selectKit.noneItem")
  get selectedContent() {
    if (!isEmpty(this.value)) {
      let content;

      const value =
        this.selectKit.options.castInteger && this._isNumeric(this.value)
          ? Number(this.value)
          : this.value;

      if (this.selectKit.valueProperty) {
        content = (this.content || []).findBy(
          this.selectKit.valueProperty,
          value
        );

        return this.selectKit.modifySelection(
          content || this.defaultItem(value, value)
        );
      } else {
        return this.selectKit.modifySelection(
          (this.content || []).filter((c) => c === value)
        );
      }
    } else {
      return this.selectKit.noneItem;
    }
  }
}
>>>>>>> a9ddbde3f6 (DEV: [gjs-codemod] renamed js to gjs)
