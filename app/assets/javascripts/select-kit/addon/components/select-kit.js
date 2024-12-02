import Component from "@ember/component";
import EmberObject, { computed, get } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { bind, cancel, next, schedule, throttle } from "@ember/runloop";
import { service } from "@ember/service";
import { isEmpty, isNone, isPresent } from "@ember/utils";
import {
  classNameBindings,
  classNames,
  tagName,
} from "@ember-decorators/component";
import { createPopper } from "@popperjs/core";
import { Promise } from "rsvp";
import { INPUT_DELAY } from "discourse-common/config/environment";
import discourseDebounce from "discourse-common/lib/debounce";
import deprecated from "discourse-common/lib/deprecated";
import { makeArray } from "discourse-common/lib/helpers";
import { bind as bindDecorator } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import {
  applyContentPluginApiCallbacks,
  applyOnChangePluginApiCallbacks,
} from "select-kit/mixins/plugin-api";
import UtilsMixin from "select-kit/mixins/utils";

export const MAIN_COLLECTION = "MAIN_COLLECTION";
export const ERRORS_COLLECTION = "ERRORS_COLLECTION";

function isDocumentRTL() {
  return document.documentElement.classList.contains("rtl");
}

/**
 * Simulates the behavior of Ember's concatenatedProperties under native class syntax
 */
function concatProtoProperty(target, key, value) {
  target.proto();
  target.prototype[key] = [
    ...makeArray(target.prototype[key]),
    ...makeArray(value),
  ];
}

/**
 * @decorator
 *
 * Apply select-kit options to a component class
 *
 */
export function selectKitOptions(options) {
  return function (target) {
    concatProtoProperty(target, "selectKitOptions", options);
  };
}

/**
 * @decorator
 *
 * Register one or more plugin API identifiers for a component class
 *
 */
export function pluginApiIdentifiers(identifiers) {
  return function (target) {
    concatProtoProperty(target, "pluginApiIdentifiers", identifiers);
  };
}

// Decorator which converts a field into a prototype property.
// This allows the value to be overridden in subclasses, even if they're still
// using the legacy Ember `.extend()` syntax.
function protoProp(prototype, key, descriptor) {
  return {
    value: descriptor.initializer?.(),
    writable: true,
    enumerable: true,
    configurable: true,
  };
}

@tagName("details")
@classNames("select-kit")
@classNameBindings(
  "selectKit.isLoading:is-loading",
  "selectKit.isExpanded:is-expanded",
  "selectKit.options.disabled:is-disabled",
  "selectKit.isHidden:is-hidden",
  "selectKit.hasSelection:has-selection"
)
@selectKitOptions({
  allowAny: false,
  showFullTitle: true,
  none: null,
  translatedNone: null,
  filterable: false,
  autoFilterable: "autoFilterable",
  filterIcon: "magnifying-glass",
  filterPlaceholder: null,
  translatedFilterPlaceholder: null,
  icon: null,
  icons: null,
  maximum: null,
  maximumLabel: null,
  minimum: null,
  autoInsertNoneItem: true,
  closeOnChange: true,
  useHeaderFilter: false,
  limitMatches: null,
  placement: isDocumentRTL() ? "bottom-end" : "bottom-start",
  verticalOffset: 3,
  filterComponent: "select-kit/select-kit-filter",
  selectedNameComponent: "selected-name",
  selectedChoiceComponent: "selected-choice",
  castInteger: false,
  focusAfterOnChange: true,
  triggerOnChangeOnTab: true,
  autofocus: false,
  placementStrategy: null,
  mobilePlacementStrategy: null,
  desktopPlacementStrategy: null,
  hiddenValues: null,
  disabled: false,
  expandedOnInsert: false,
  formName: null,
})
@pluginApiIdentifiers(["select-kit"])
export default class SelectKit extends Component.extend(UtilsMixin) {
  @service appEvents;

  singleSelect = false;
  multiSelect = false;

  @protoProp tabindex = 0;
  @protoProp content = null;
  @protoProp value = null;
  @protoProp selectKit = null;
  @protoProp mainCollection = null;
  @protoProp errorsCollection = null;
  @protoProp options = null;
  @protoProp valueProperty = "id";
  @protoProp nameProperty = "name";
  @protoProp labelProperty = null;
  @protoProp titleProperty = null;
  @protoProp langProperty = null;

  init() {
    super.init(...arguments);

    this._searchPromise = null;

    this.set("errorsCollection", []);
    this._collections = [ERRORS_COLLECTION, MAIN_COLLECTION];

    !this.options && this.set("options", EmberObject.create({}));

    this.handleDeprecations();

    this.set(
      "selectKit",
      EmberObject.create({
        uniqueID: this.id || guidFor(this),
        valueProperty: this.valueProperty,
        nameProperty: this.nameProperty,
        labelProperty: this.labelProperty,
        titleProperty: this.titleProperty,
        langProperty: this.langProperty,
        options: EmberObject.create(),

        isLoading: false,
        isHidden: false,
        isExpanded: false,
        isFilterExpanded: false,
        enterDisabled: false,
        hasSelection: false,
        hasNoContent: true,
        highlighted: null,
        noneItem: null,
        newItem: null,
        filter: null,

        modifyContent: bind(this, this._modifyContentWrapper),
        modifySelection: bind(this, this._modifySelectionWrapper),
        modifyComponentForRow: bind(this, this._modifyComponentForRowWrapper),
        modifyContentForCollection: bind(
          this,
          this._modifyContentForCollectionWrapper
        ),
        modifyComponentForCollection: bind(
          this,
          this._modifyComponentForCollectionWrapper
        ),

        toggle: bind(this, this._toggle),
        close: bind(this, this._close),
        open: bind(this, this._open),
        highlightNext: bind(this, this._highlightNext),
        highlightPrevious: bind(this, this._highlightPrevious),
        highlightLast: bind(this, this._highlightLast),
        highlightFirst: bind(this, this._highlightFirst),
        deselectLast: bind(this, this._deselectLast),
        change: bind(this, this._onChangeWrapper),
        select: bind(this, this.select),
        deselect: bind(this, this.deselect),
        deselectByValue: bind(this, this.deselectByValue),
        append: bind(this, this.append),
        cancelSearch: bind(this, this._cancelSearch),
        triggerSearch: bind(this, this.triggerSearch),
        focusFilter: bind(this, this._focusFilter),

        onOpen: bind(this, this._onOpenWrapper),
        onClose: bind(this, this._onCloseWrapper),
        onInput: bind(this, this._onInput),
        onClearSelection: bind(this, this._onClearSelection),
        onHover: bind(this, this._onHover),
        onKeydown: bind(this, this._onKeydownWrapper),

        mainElement: bind(this, this._mainElement),
        headerElement: bind(this, this._headerElement),
        bodyElement: bind(this, this._bodyElement),
      })
    );
  }

  _modifyComponentForRowWrapper(collection, item) {
    let component = this.modifyComponentForRow(collection, item);
    return component || "select-kit/select-kit-row";
  }

  modifyComponentForRow() {}

  _modifyContentForCollectionWrapper(identifier) {
    let collection = this.modifyContentForCollection(identifier);

    if (!collection) {
      switch (identifier) {
        case ERRORS_COLLECTION:
          collection = this.errorsCollection;
          break;
        default:
          collection = this.mainCollection;
          break;
      }
    }

    return collection;
  }

  modifyContentForCollection() {}

  _modifyComponentForCollectionWrapper(identifier) {
    let component = this.modifyComponentForCollection(identifier);

    if (!component) {
      switch (identifier) {
        case ERRORS_COLLECTION:
          component = "select-kit/errors-collection";
          break;
        default:
          component = "select-kit/select-kit-collection";
          break;
      }
    }

    return component;
  }

  modifyComponentForCollection() {}

  didUpdateAttrs() {
    super.didUpdateAttrs(...arguments);

    this.handleDeprecations();
  }

  didInsertElement() {
    super.didInsertElement(...arguments);

    this.appEvents.on("keyboard-visibility-change", this, this._updatePopper);

    if (this.selectKit.options.expandedOnInsert) {
      next(() => {
        this._open();
      });
    }
  }

  click(event) {
    event.preventDefault();
    event.stopPropagation();
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    this._cancelSearch();

    this.appEvents.off("keyboard-visibility-change", this, this._updatePopper);

    if (this.popper) {
      this.popper.destroy();
      this.popper = null;
    }
  }

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    const deprecatedOptions = this._resolveDeprecatedOptions();
    const mergedOptions = Object.assign({}, ...this.selectKitOptions);
    Object.keys(mergedOptions).forEach((key) => {
      if (isPresent(this.options[key])) {
        this.selectKit.options.set(key, this.options[key]);
        return;
      }

      if (isPresent(deprecatedOptions[`options.${key}`])) {
        this.selectKit.options.set(key, deprecatedOptions[`options.${key}`]);
        return;
      }

      const value = mergedOptions[key];

      if (
        key === "componentForRow" ||
        key === "contentForCollection" ||
        key === "componentForCollection"
      ) {
        if (typeof value === "string") {
          this.selectKit.options.set(key, () => value);
        } else {
          this.selectKit.options.set(key, bind(this, value));
        }

        return;
      }

      if (typeof value === "string" && !value.includes(".") && value in this) {
        const computedValue = get(this, value);
        if (typeof computedValue !== "function") {
          this.selectKit.options.set(key, computedValue);
          return;
        }
      }

      this.selectKit.options.set(key, value);
    });

    this.selectKit.setProperties({
      hasSelection: !isEmpty(this.value),
      noneItem: this._modifyNoSelectionWrapper(),
      newItem: null,
    });

    if (this.selectKit.isExpanded) {
      this.triggerSearch();
    }

    if (this.computeContent) {
      this._deprecated(
        `The \`computeContent()\` function is deprecated pass a \`content\` attribute or define a \`content\` computed property in your component.`
      );

      this.set("content", this.computeContent());
    }
  }

  @computed("content.[]", "selectKit.filter")
  get autoFilterable() {
    return (
      this.selectKit.filter &&
      this.options.autoFilterable &&
      this.content.length > 15
    );
  }

  @computed("selectedContent.[]", "mainCollection.[]", "errorsCollection.[]")
  get collections() {
    return this._collections.map((identifier) => {
      return {
        identifier,
        content: this.selectKit.modifyContentForCollection(identifier),
      };
    });
  }

  createContentFromInput(input) {
    return input;
  }

  validateCreate(filter, content) {
    this.clearErrors();

    return (
      filter.length > 0 &&
      content &&
      !content.map((c) => this.getValue(c)).includes(filter) &&
      !makeArray(this.value).includes(filter)
    );
  }

  validateSelect() {
    this.clearErrors();

    const selection = makeArray(this.value);

    const maximum = this.selectKit.options.maximum;
    if (maximum && selection.length >= maximum) {
      const key =
        this.selectKit.options.maximumLabel || "select_kit.max_content_reached";
      this.addError(i18n(key, { count: maximum }));
      return false;
    }

    return true;
  }

  addError(error) {
    if (!this.errorsCollection.includes(error)) {
      this.errorsCollection.pushObject(error);
    }

    this._safeAfterRender(() => this._updatePopper());
  }

  clearErrors() {
    if (!this.element || this.isDestroyed || this.isDestroying) {
      return;
    }

    this.set("errorsCollection", []);
  }

  prependCollection(identifier) {
    this._collections.unshift(identifier);
  }

  appendCollection(identifier) {
    this._collections.push(identifier);
  }

  insertCollectionAtIndex(identifier, index) {
    this._collections.insertAt(index, identifier);
  }

  insertBeforeCollection(identifier, insertedIdentifier) {
    const index = this._collections.indexOf(identifier);
    this.insertCollectionAtIndex(insertedIdentifier, index - 1);
  }

  insertAfterCollection(identifier, insertedIdentifier) {
    const index = this._collections.indexOf(identifier);
    this.insertCollectionAtIndex(insertedIdentifier, index + 1);
  }

  _onInput(event) {
    this._updatePopper();

    if (this._searchPromise) {
      cancel(this._searchPromise);
    }

    this.selectKit.set("isLoading", true);

    discourseDebounce(
      this,
      this._debouncedInput,
      event.target.value,
      INPUT_DELAY
    );
  }

  _debouncedInput(filter) {
    this.selectKit.set("filter", filter);
    this.triggerSearch(filter);
  }

  _onChangeWrapper(value, items) {
    this.selectKit.set("filter", null);

    return new Promise((resolve) => {
      if (!this.selectKit.valueProperty && this.selectKit.noneItem === value) {
        value = null;
        items = [];
      }

      value = makeArray(value);
      items = makeArray(items);

      if (this.multiSelect) {
        items = items.filter(
          (i) =>
            i !== this.newItem &&
            i !== this.noneItem &&
            this.getValue(i) !== null
        );

        if (this.selectKit.options.maximum === 1) {
          value = value.slice(0, 1);
          items = items.slice(0, 1);
        }
      }

      if (this.singleSelect) {
        value = isPresent(value.firstObject) ? value.firstObject : null;
        items = isPresent(items.firstObject) ? items.firstObject : null;
      }

      this._boundaryActionHandler("onChange", value, items);

      applyOnChangePluginApiCallbacks(value, items, this);

      resolve(items);
    }).finally(() => {
      if (!this.isDestroying && !this.isDestroyed) {
        if (
          this.selectKit.options.closeOnChange ||
          (isPresent(value) && this.selectKit.options.maximum === 1)
        ) {
          this.selectKit.close(event);
        }

        if (this.selectKit.options.focusAfterOnChange) {
          this._safeAfterRender(() => {
            this._focusFilter();
            this._updatePopper();
          });
        }
      }
    });
  }

  _modifyContentWrapper(content) {
    content = this.modifyContent(content);

    return applyContentPluginApiCallbacks(content, this);
  }

  modifyContent(content) {
    return content;
  }

  _modifyNoSelectionWrapper() {
    return this.modifyNoSelection();
  }

  modifyNoSelection() {
    if (this.selectKit.options.translatedNone) {
      return this.defaultItem(null, this.selectKit.options.translatedNone);
    }

    let none = this.selectKit.options.none;
    if (isNone(none) && !this.selectKit.options.allowAny) {
      return null;
    }

    if (
      isNone(none) &&
      this.selectKit.options.allowAny &&
      !this.selectKit.isExpanded
    ) {
      return null;
    }

    let item;
    switch (typeof none) {
      case "string":
        item = this.defaultItem(null, i18n(none));
        break;
      default:
        item = none;
    }

    return item;
  }

  _modifySelectionWrapper(item) {
    return this.modifySelection(item);
  }

  modifySelection(item) {
    return item;
  }

  _onKeydownWrapper(event) {
    return this._boundaryActionHandler("onKeydown", event);
  }

  _mainElement() {
    return document.querySelector(`#${this.selectKit.uniqueID}`);
  }

  _headerElement() {
    return this.selectKit.mainElement().querySelector("summary");
  }

  _bodyElement() {
    return this.selectKit.mainElement().querySelector(".select-kit-body");
  }

  _onHover(value, item) {
    throttle(this, this._highlight, item, 25, true);
  }

  _highlight(item) {
    this.selectKit.set("highlighted", item);
  }

  _boundaryActionHandler(actionName, ...params) {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    let boundaryAction = true;

    const privateActionName = `_${actionName}`;
    const privateAction = get(this, privateActionName);
    if (privateAction) {
      boundaryAction = privateAction.call(this, ...params);
    }

    if (this.actions) {
      const componentAction = get(this.actions, actionName);
      if (boundaryAction && componentAction) {
        boundaryAction = componentAction.call(this, ...params);
      }
    }

    const action = get(this, actionName);
    if (boundaryAction && action) {
      boundaryAction = action.call(this, ...params);
    }

    return boundaryAction;
  }

  deselect() {
    this.clearErrors();
    this.selectKit.change(null, null);
  }

  deselectByValue(value) {
    if (!value) {
      return;
    }

    const item = this.itemForValue(value, this.selectedContent);
    this.deselect(item);
  }

  append() {
    // do nothing on general case
  }

  search(filter) {
    let content = this.content || [];
    if (filter) {
      filter = this._normalize(filter);
      content = content.filter((c) => {
        const name = this._normalize(this.getName(c));
        return name?.includes(filter);
      });
    }
    return content;
  }

  triggerSearch(filter) {
    this._searchPromise && cancel(this._searchPromise);

    this._searchPromise = this._searchWrapper(filter || this.selectKit.filter);
  }

  _searchWrapper(filter) {
    if (this.isDestroyed || this.isDestroying) {
      return Promise.resolve([]);
    }

    this.clearErrors();
    this.setProperties({
      mainCollection: [],
      "selectKit.isLoading": true,
      "selectKit.enterDisabled": true,
    });
    this._safeAfterRender(() => this._updatePopper());

    let content = [];

    return Promise.resolve(this.search(filter))
      .then((result) => {
        if (this.isDestroyed || this.isDestroying) {
          return [];
        }

        if (this.selectKit.options.maximum === 0) {
          this.set("selectKit.isLoading", false);
          this.set("selectKit.hasNoContent", false);
          return [];
        }

        content = content.concat(makeArray(result));
        content = this.selectKit.modifyContent(content).filter(Boolean);

        if (this.selectKit.valueProperty) {
          content = content.uniqBy(this.selectKit.valueProperty);
        } else {
          content = content.uniq();
        }

        if (this.selectKit.options.limitMatches) {
          content = content.slice(0, this.selectKit.options.limitMatches);
        }

        const noneItem = this.selectKit.noneItem;
        if (
          this.selectKit.options.allowAny &&
          filter &&
          this.getName(noneItem) !== filter
        ) {
          filter = this.createContentFromInput(filter);
          if (this.validateCreate(filter, content)) {
            this.selectKit.set("newItem", this.defaultItem(filter, filter));
            content.unshift(this.selectKit.newItem);
          }
        }

        const hasNoContent = isEmpty(content);
        if (
          this.selectKit.hasSelection &&
          noneItem &&
          this.selectKit.options.autoInsertNoneItem
        ) {
          content.unshift(noneItem);
        }

        this.set("mainCollection", content);

        this.selectKit.setProperties({
          highlighted:
            this.singleSelect && this.value
              ? this.itemForValue(this.value, this.mainCollection)
              : isEmpty(this.selectKit.filter)
              ? null
              : this.mainCollection.firstObject,
          isLoading: false,
          hasNoContent,
        });

        this._safeAfterRender(() => {
          if (this.selectKit.isExpanded) {
            this._updatePopper();
            this._focusFilter();
          }
        });
      })
      .finally(() => {
        if (this.isDestroyed || this.isDestroying) {
          return;
        }
        this.set("selectKit.enterDisabled", false);
      });
  }

  _safeAfterRender(fn) {
    next(() => {
      schedule("afterRender", () => {
        if (!this.element || this.isDestroyed || this.isDestroying) {
          return;
        }

        fn();
      });
    });
  }

  _scrollToRow(rowItem, preventScroll = true) {
    const value = this.getValue(rowItem);

    let rowContainer;
    if (isPresent(value)) {
      rowContainer = this.element.querySelector(
        `.select-kit-row[data-value="${value}"]`
      );
    } else {
      rowContainer = this.element.querySelector(".select-kit-row.is-none");
    }

    rowContainer?.focus({ preventScroll });
  }

  _highlightLast() {
    const highlighted = this.mainCollection.objectAt(
      this.mainCollection.length - 1
    );
    if (highlighted) {
      this._scrollToRow(highlighted, false);
      this.set("selectKit.highlighted", highlighted);
    }
  }

  _highlightFirst() {
    const highlighted = this.mainCollection.objectAt(0);
    if (highlighted) {
      this._scrollToRow(highlighted, false);
      this.set("selectKit.highlighted", highlighted);
    }
  }

  _highlightNext() {
    let highlightedIndex = this.mainCollection.indexOf(
      this.selectKit.highlighted
    );
    const count = this.mainCollection.length;

    if (highlightedIndex < count - 1) {
      highlightedIndex = highlightedIndex + 1;
    } else {
      if (this.selectKit.isFilterExpanded) {
        this._focusFilter();
        this.set("selectKit.highlighted", null);
        return;
      } else {
        highlightedIndex = 0;
      }
    }

    const highlighted = this.mainCollection.objectAt(highlightedIndex);
    if (highlighted) {
      this._scrollToRow(highlighted, false);
      this.set("selectKit.highlighted", highlighted);
    }
  }

  _highlightPrevious() {
    let highlightedIndex = this.mainCollection.indexOf(
      this.selectKit.highlighted
    );
    const count = this.mainCollection.length;

    if (highlightedIndex > 0) {
      highlightedIndex = highlightedIndex - 1;
    } else {
      if (this.selectKit.isFilterExpanded) {
        this._focusFilter();
        this.set("selectKit.highlighted", null);
        return;
      } else {
        highlightedIndex = count - 1;
      }
    }

    const highlighted = this.mainCollection.objectAt(highlightedIndex);
    if (highlighted) {
      this._scrollToRow(highlighted, false);
      this.set("selectKit.highlighted", highlighted);
    }
  }

  _deselectLast() {
    if (this.selectKit.hasSelection) {
      this.deselectByValue(this.value[this.value.length - 1]);
    }
  }

  select(value, item) {
    if (!isPresent(value)) {
      this._onClearSelection();
    } else {
      const existingItem = this.findValue(this.mainCollection, item);
      if (existingItem) {
        if (!this.validateSelect(item)) {
          return;
        }
      }

      this.selectKit.change(value, item || this.defaultItem(value, value));
    }
  }

  _onClearSelection() {
    this.selectKit.change(null, null);
  }

  _onOpenWrapper() {
    return this._boundaryActionHandler("onOpen");
  }

  _cancelSearch() {
    this._searchPromise && cancel(this._searchPromise);
  }

  _onCloseWrapper() {
    this._cancelSearch();
    this.set("selectKit.highlighted", null);

    return this._boundaryActionHandler("onClose");
  }

  _toggle(event) {
    if (this.selectKit.isExpanded) {
      this._close(event);
    } else {
      this._open(event);
    }
  }

  _close(event) {
    if (!this.selectKit.isExpanded) {
      return;
    }

    this.selectKit.mainElement().open = false;

    this.clearErrors();

    const inModal = this.element.closest(".fixed-modal");
    if (inModal && this.site.mobileView) {
      const modalBody = inModal.querySelector(".modal-body");
      modalBody.style = "";
    }

    this.selectKit.onClose(event);

    this.selectKit.setProperties({
      isExpanded: false,
      filter: null,
    });
  }

  _open(event) {
    if (this.selectKit.isExpanded) {
      return;
    }

    this.selectKit.mainElement().open = true;
    this.clearErrors();
    this.selectKit.onOpen(event);

    if (!this.popper) {
      const inModal = this.element.closest(".fixed-modal .modal-body");
      const anchor = document.querySelector(
        `#${this.selectKit.uniqueID}-header`
      );
      const popper = document.querySelector(`#${this.selectKit.uniqueID}-body`);
      const strategy = this._computePlacementStrategy();

      let bottomOffset = 0;
      if (this.capabilities.isIOS) {
        bottomOffset +=
          parseInt(
            getComputedStyle(document.documentElement)
              .getPropertyValue("--safe-area-inset-bottom")
              .trim(),
            10
          ) || 0;
      }
      if (this.site.mobileView) {
        bottomOffset +=
          parseInt(
            getComputedStyle(document.documentElement)
              .getPropertyValue("--footer-nav-height")
              .trim(),
            10
          ) || 0;
      }

      this.popper = createPopper(anchor, popper, {
        eventsEnabled: false,
        strategy,
        placement: this.selectKit.options.placement,
        modifiers: [
          {
            name: "eventListeners",
            options: {
              resize: this.site.desktopView,
              scroll: this.site.desktopView,
            },
          },
          {
            name: "flip",
            enabled: !inModal,
            options: {
              padding: {
                top:
                  parseInt(
                    document.documentElement.style.getPropertyValue(
                      "--header-offset"
                    ),
                    10
                  ) || 0,
                bottom: bottomOffset,
              },
            },
          },
          {
            name: "offset",
            options: {
              offset: [0, this.selectKit.options.verticalOffset],
            },
          },
          {
            name: "applySmallScreenOffset",
            enabled: window.innerWidth <= 450,
            phase: "main",
            fn({ state }) {
              if (!inModal) {
                let { x } = state.elements.reference.getBoundingClientRect();
                if (strategy === "fixed") {
                  state.modifiersData.popperOffsets.x = 0 + 10;
                } else {
                  state.modifiersData.popperOffsets.x = -x + 10;
                }
              }
            },
          },
          {
            name: "applySmallScreenMaxWidth",
            enabled: window.innerWidth <= 450,
            phase: "beforeWrite",
            fn: ({ state }) => {
              if (inModal) {
                const innerModal = document.querySelector(
                  ".fixed-modal div.modal-inner-container"
                );

                if (innerModal) {
                  if (this.multiSelect) {
                    state.styles.popper.width = `${this.element.offsetWidth}px`;
                  } else {
                    state.styles.popper.width = `${
                      innerModal.clientWidth - 20
                    }px`;
                  }
                }
              } else {
                state.styles.popper.width = `${window.innerWidth - 20}px`;
              }
            },
          },
          {
            name: "minWidth",
            enabled: window.innerWidth > 450,
            phase: "beforeWrite",
            requires: ["computeStyles"],
            fn: ({ state }) => {
              state.styles.popper.minWidth = `${Math.max(
                state.rects.reference.width,
                220
              )}px`;
            },
            effect: ({ state }) => {
              state.elements.popper.style.minWidth = `${Math.max(
                state.elements.reference.offsetWidth,
                220
              )}px`;
            },
          },
          {
            name: "modalHeight",
            enabled: !!(inModal && this.site.mobileView),
            phase: "afterWrite",
            fn: ({ state }) => {
              inModal.style = "";
              inModal.style.height =
                inModal.clientHeight + state.rects.popper.height + "px";
            },
          },
        ],
      });
    }

    this.selectKit.setProperties({
      isExpanded: true,
      isFilterExpanded:
        this.selectKit.options.filterable || this.selectKit.options.allowAny,
    });

    if (this.selectKit.options.useHeaderFilter) {
      this._focusFilterInput();
    }

    this.triggerSearch();

    this._safeAfterRender(() => {
      this._focusFilter();
      this._scrollToCurrent();
      this._updatePopper();
    });
  }

  _scrollToCurrent() {
    if (this.value && this.mainCollection) {
      let highlighted;
      if (this.valueProperty) {
        highlighted = this.mainCollection.findBy(
          this.valueProperty,
          this.value
        );
      } else {
        const index = this.mainCollection.indexOf(this.value);
        highlighted = this.mainCollection.objectAt(index);
      }

      if (highlighted) {
        this._scrollToRow(highlighted, false);
        this.set("selectKit.highlighted", highlighted);
      }
    }
  }

  _focusFilter(forceHeader = false) {
    if (!this.selectKit.mainElement()) {
      return;
    }

    if (!this.selectKit.mainElement().open) {
      const headerContainer = this.getHeader();
      headerContainer && headerContainer.focus({ preventScroll: true });
      return;
    }

    // setting focus as early as possible is best for iOS
    // because render/promise delays may cause keyboard not to show
    if (!forceHeader) {
      this._focusFilterInput();
    }

    this._safeAfterRender(() => {
      const input = this.getFilterInput();
      if (!forceHeader && input) {
        this._focusFilterInput();
      } else if (!this.selectKit.options.preventHeaderFocus) {
        const headerContainer = this.getHeader();
        headerContainer && headerContainer.focus({ preventScroll: true });
      }
    });
  }

  _focusFilterInput() {
    const input = this.getFilterInput();

    if (input && document.activeElement !== input) {
      input.focus({ preventScroll: true });

      if (typeof input.selectionStart === "number") {
        input.selectionStart = input.selectionEnd = input.value.length;
      }
    }
  }

  getFilterInput() {
    return document.querySelector(`#${this.selectKit.uniqueID}-filter input`);
  }

  getHeader() {
    return document.querySelector(`#${this.selectKit.uniqueID}-header`);
  }

  handleDeprecations() {
    this._deprecateValueAttribute();
    this._deprecateMutations();
    this._handleDeprecatedArgs();
  }

  @bindDecorator
  _updatePopper() {
    this.popper?.update?.();
  }

  _computePlacementStrategy() {
    let placementStrategy = this.selectKit.options.placementStrategy;

    if (placementStrategy) {
      return placementStrategy;
    }

    if (this.site.mobileView) {
      placementStrategy =
        this.selectKit.options.mobilePlacementStrategy || "absolute";
    } else {
      placementStrategy =
        this.selectKit.options.desktopPlacementStrategy || "fixed";
    }

    return placementStrategy;
  }

  _deprecated(text) {
    deprecated(text, {
      since: "v2.4.0",
      dropFrom: "2.9.0.beta1",
      id: "discourse.select-kit",
    });
  }

  _deprecateValueAttribute() {
    if (this.valueAttribute || this.valueAttribute === null) {
      this._deprecated(
        "The `valueAttribute` is deprecated. Use `valueProperty` instead"
      );

      this.set("valueProperty", this.valueAttribute);
    }
  }

  _deprecateMutations() {
    this.actions ??= {};

    if (!this.onChange && !this.actions.onChange) {
      this._deprecated(
        "Implicit mutation has been deprecated, please use `onChange` handler"
      );

      this.actions.onChange =
        this.onSelect ||
        this.actions.onSelect ||
        ((value) => this.set("value", value));
    }
  }

  _resolveDeprecatedOptions() {
    const migrations = {
      allowAny: "options.allowAny",
      allowCreate: "options.allowAny",
      filterable: "options.filterable",
      excludeCategoryId: "options.excludeCategoryId",
      scopedCategoryId: "options.scopedCategoryId",
      allowUncategorized: "options.allowUncategorized",
      none: "options.none",
      rootNone: "options.none",
      disabled: "options.disabled",
      isDisabled: "options.disabled",
      rootNoneLabel: "options.none",
      showFullTitle: "options.showFullTitle",
      title: "options.translatedNone",
      maximum: "options.maximum",
      minimum: "options.minimum",
      i18nPostfix: "options.i18nPostfix",
      i18nPrefix: "options.i18nPrefix",
      btnCustomClasses: "options.btnCustomClasses",
      castInteger: "options.castInteger",
    };

    const resolvedDeprecations = {};

    Object.keys(migrations).forEach((from) => {
      const to = migrations[from];
      if (this.get(from) && !this.get(to)) {
        this._deprecated(
          `The \`${from}\` attribute is deprecated. Use \`${to}\` instead`
        );

        resolvedDeprecations[(to, this.get(from))];
      }
    });

    return resolvedDeprecations;
  }

  _handleDeprecatedArgs() {
    const migrations = {
      headerIcon: "icon",
      onExpand: "onOpen",
      onCollapse: "onClose",
    };

    Object.keys(migrations).forEach((from) => {
      const to = migrations[from];
      if (this.get(from) && !this.get(to)) {
        this._deprecated(
          `The \`${from}\` attribute is deprecated. Use \`${to}\` instead`
        );

        this.set(to, this.get(from));
      }
    });
  }
}

// Keep the concatenatedProperties behavior for legacy `.extend()` subclasses
SelectKit.prototype.concatenatedProperties = [
  ...SelectKit.prototype.concatenatedProperties,
  "selectKitOptions",
  "pluginApiIdentifiers",
];
