import { concat } from "@ember/helper";
import { computed } from "@ember/object";
import { next } from "@ember/runloop";
import { isPresent } from "@ember/utils";
import { classNames } from "@ember-decorators/component";
import { and, not } from "truth-helpers";
import componentForCollection from "discourse/helpers/component-for-collection";
import { makeArray } from "discourse/lib/helpers";
import { i18n } from "discourse-i18n";
import SelectKitComponent, {
  pluginApiIdentifiers,
  resolveComponent,
  selectKitOptions,
} from "select-kit/components/select-kit";
import SelectKitBody from "select-kit/components/select-kit/select-kit-body";
import { isNumeric } from "select-kit/lib/input-utils";
import MultiSelectFilter from "./multi-select/multi-select-filter";
import MultiSelectHeader from "./multi-select/multi-select-header";

@classNames("multi-select")
@selectKitOptions({
  none: "select_kit.default_header_text",
  clearable: true,
  filterable: true,
  filterIcon: null,
  closeOnChange: false,
  autoInsertNoneItem: false,
  headerComponent: MultiSelectHeader,
  filterComponent: MultiSelectFilter,
  autoFilterable: true,
  caretDownIcon: "caretIcon",
  caretUpIcon: "caretIcon",
  useHeaderFilter: false,
})
@pluginApiIdentifiers(["multi-select"])
export default class MultiSelect extends SelectKitComponent {
  multiSelect = true;

  @computed("value.[]")
  get caretIcon() {
    const maximum = this.selectKit.options.maximum;
    return maximum && makeArray(this.value).length >= parseInt(maximum, 10)
      ? null
      : "plus";
  }

  search(filter) {
    return super
      .search(filter)
      .filter((content) => !makeArray(this.selectedContent).includes(content));
  }

  append(values) {
    const existingItems = values
      .map((value) => {
        const defaultItem = this.defaultItem(value, value);
        const existingItem =
          this.findValue(this.mainCollection, defaultItem) ||
          this.findName(this.mainCollection, defaultItem);
        if (!existingItem) {
          if (this.validateCreate(value, this.content)) {
            return value;
          }
        } else if (this.validateSelect(existingItem)) {
          return this.getValue(existingItem);
        }
      })
      .filter(Boolean);

    const newValues = makeArray(this.value).concat(existingItems);
    const newContent = makeArray(this.selectedContent).concat(
      makeArray(existingItems)
    );

    this.selectKit.change(newValues, newContent);
  }

  deselect(item) {
    this.clearErrors();

    const newContent = this.selectedContent.filter(
      (content) => this.getValue(item) !== this.getValue(content)
    );

    this.selectKit.change(
      this.valueProperty ? newContent.mapBy(this.valueProperty) : newContent,
      newContent
    );
  }

  select(value, item) {
    if (this.selectKit.hasSelection && this.selectKit.options.maximum === 1) {
      this.selectKit.deselectByValue(
        this.getValue(this.selectedContent.firstObject)
      );
      next(() => {
        this.selectKit.select(value, item);
      });
      return;
    }

    if (!isPresent(value)) {
      if (!this.validateSelect(this.selectKit.highlighted)) {
        return;
      }

      this.selectKit.change(
        makeArray(this.value).concat(
          makeArray(this.getValue(this.selectKit.highlighted))
        ),
        makeArray(this.selectedContent).concat(
          makeArray(this.selectKit.highlighted)
        )
      );
    } else {
      const existingItem = this.findValue(
        this.mainCollection,
        this.selectKit.valueProperty ? item : value
      );
      if (existingItem) {
        if (!this.validateSelect(item)) {
          return;
        }
      }

      const newValues = makeArray(this.value).concat(makeArray(value));
      const newContent = makeArray(this.selectedContent).concat(
        makeArray(item)
      );

      this.selectKit.change(
        [...new Set(newValues)],
        newContent.length
          ? newContent
          : makeArray(this.defaultItem(value, value))
      );
    }
  }

  @computed("value.[]", "content.[]", "selectKit.noneItem")
  get selectedContent() {
    const value = makeArray(this.value).map((v) =>
      this.selectKit.options.castInteger && isNumeric(v) ? Number(v) : v
    );

    if (value.length) {
      let content = [];

      value.forEach((v) => {
        if (this.selectKit.valueProperty) {
          const c = makeArray(this.content).find(
            (item) => item[this.selectKit.valueProperty] === v
          );
          if (c) {
            content.push(c);
          }
        } else {
          if (makeArray(this.content).includes(v)) {
            content.push(v);
          }
        }
      });

      return this.selectKit.modifySelection(content);
    }

    return null;
  }

  _onKeydown(event) {
    if (
      event.code === "Enter" &&
      event.target.classList.contains("selected-name")
    ) {
      event.stopPropagation();
      this.selectKit.deselectByValue(event.target.dataset.value);
      return false;
    }

    if (event.code === "Backspace") {
      event.stopPropagation();

      const input = this.getFilterInput();
      if (input && input.value.length === 0) {
        const selected = this.element.querySelectorAll(
          ".select-kit-header .choice.select-kit-selected-name"
        );

        if (selected.length) {
          const lastSelected = selected[selected.length - 1];
          if (lastSelected) {
            if (lastSelected === document.activeElement) {
              this.deselect(this.selectedContent.lastObject);
            } else {
              lastSelected.focus();
            }
          }
        }
      }
    }

    return true;
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
        {{#unless this.selectKit.options.useHeaderFilter}}
          {{#let
            (resolveComponent this this.selectKit.options.filterComponent)
            as |FilterComponent|
          }}
            <FilterComponent
              @selectKit={{this.selectKit}}
              @id={{concat this.selectKit.uniqueID "-filter"}}
            />
          {{/let}}

          {{#if this.selectedContent.length}}
            <div class="selected-content">
              {{#let
                (resolveComponent
                  this this.selectKit.options.selectedChoiceComponent
                )
                as |SelectedChoiceComponent|
              }}
                {{#each this.selectedContent as |item|}}
                  <SelectedChoiceComponent
                    @item={{item}}
                    @selectKit={{this.selectKit}}
                    @mandatoryValues={{@mandatoryValues}}
                  />
                {{/each}}
              {{/let}}
            </div>
          {{/if}}
        {{/unless}}

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
