import { concat } from "@ember/helper";
import { computed } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { classNames } from "@ember-decorators/component";
import { and, not } from "truth-helpers";
import componentForCollection from "discourse/helpers/component-for-collection";
import { i18n } from "discourse-i18n";
import SelectKitComponent, {
  pluginApiIdentifiers,
  resolveComponent,
  selectKitOptions,
} from "select-kit/components/select-kit";
import SelectKitBody from "select-kit/components/select-kit/select-kit-body";
import { isNumeric } from "select-kit/lib/input-utils";
import SingleSelectHeader from "./select-kit/single-select-header";

@classNames("single-select")
@selectKitOptions({
  headerComponent: SingleSelectHeader,
})
@pluginApiIdentifiers(["single-select"])
export default class SingleSelect extends SelectKitComponent {
  singleSelect = true;

  @computed("value", "content.[]", "selectKit.noneItem")
  get selectedContent() {
    if (!isEmpty(this.value)) {
      let content;

      const value =
        this.selectKit.options.castInteger && isNumeric(this.value)
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

  <template>
    {{#unless this.selectKit.isHidden}}
      {{#let
        (resolveComponent this this.selectKit.options.headerComponent)
        as |HeaderComponent|
      }}
        <HeaderComponent
          @tabindex={{this.tabindex}}
          @value={{this.value}}
          @selectedContent={{this.selectedContent}}
          @selectKit={{this.selectKit}}
          @id={{concat this.selectKit.uniqueID "-header"}}
        />
      {{/let}}

      <SelectKitBody
        @selectKit={{this.selectKit}}
        @id={{concat this.selectKit.uniqueID "-body"}}
      >
        {{#let
          (resolveComponent this this.selectKit.options.filterComponent)
          as |FilterComponent|
        }}
          <FilterComponent
            @selectKit={{this.selectKit}}
            @id={{concat this.selectKit.uniqueID "-filter"}}
          />
        {{/let}}

        {{#each this.collections as |collection|}}
          {{#let
            (resolveComponent
              this (componentForCollection collection.identifier this.selectKit)
            )
            as |CollectionComponent|
          }}
            <CollectionComponent
              @collection={{collection}}
              @selectKit={{this.selectKit}}
              @value={{this.value}}
            />
          {{/let}}
        {{/each}}

        {{#if this.selectKit.filter}}
          {{#if
            (and this.selectKit.hasNoContent (not this.selectKit.isLoading))
          }}
            <span class="no-content" role="alert">
              {{i18n "select_kit.no_content"}}
            </span>
          {{else}}
            <span class="results-count" role="alert">
              {{i18n
                "select_kit.results_count"
                count=this.mainCollection.length
              }}
            </span>
          {{/if}}
        {{/if}}

      </SelectKitBody>
    {{/unless}}
  </template>
}
