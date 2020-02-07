import { computed, default as EmberObject } from "@ember/object";
import Component from "@ember/component";
import deprecated from "discourse-common/lib/deprecated";
import { makeArray } from "discourse-common/lib/helpers";
import { get } from "@ember/object";
import UtilsMixin from "select-kit/mixins/utils";
import PluginApiMixin from "select-kit/mixins/plugin-api";
import Mixin from "@ember/object/mixin";
import { isEmpty, isNone } from "@ember/utils";
import {
  next,
  debounce,
  cancel,
  throttle,
  bind,
  schedule
} from "@ember/runloop";
import { Promise } from "rsvp";
import {
  applyHeaderContentPluginApiCallbacks,
  applyModifyNoSelectionPluginApiCallbacks,
  applyContentPluginApiCallbacks,
  applyOnOpenPluginApiCallbacks,
  applyOnClosePluginApiCallbacks,
  applyOnInputPluginApiCallbacks
} from "select-kit/mixins/plugin-api";

export const MAIN_COLLECTION = "MAIN_COLLECTION";
export const ERRORS_COLLECTION = "ERRORS_COLLECTION";

const EMPTY_OBJECT = Object.freeze({});
const SELECT_KIT_OPTIONS = Mixin.create({
  mergedProperties: ["selectKitOptions"],
  selectKitOptions: EMPTY_OBJECT
});

export default Component.extend(
  SELECT_KIT_OPTIONS,
  PluginApiMixin,
  UtilsMixin,
  {
    pluginApiIdentifiers: ["select-kit"],
    layoutName: "select-kit/templates/components/select-kit",
    classNames: ["select-kit"],
    classNameBindings: [
      "selectKit.isLoading:is-loading",
      "selectKit.isExpanded:is-expanded",
      "selectKit.isDisabled:is-disabled",
      "selectKit.isHidden:is-hidden",
      "selectKit.hasSelection:has-selection"
    ],
    tabindex: 0,
    content: null,
    value: null,
    selectKit: null,
    mainCollection: null,
    errorsCollection: null,
    options: null,
    valueProperty: "id",
    nameProperty: "name",

    init() {
      this._super(...arguments);

      this._searchPromise = null;

      this.set("errorsCollection", []);
      this._collections = [ERRORS_COLLECTION, MAIN_COLLECTION];

      !this.options && this.set("options", EmberObject.create({}));

      this.handleDeprecations();

      this.set(
        "selectKit",
        EmberObject.create({
          uniqueID: Ember.guidFor(this),
          valueProperty: this.valueProperty,
          nameProperty: this.nameProperty,
          options: EmberObject.create(),

          isLoading: false,
          isHidden: false,
          isExpanded: false,
          isFilterExpanded: false,
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
          change: bind(this, this._onChangeWrapper),
          select: bind(this, this.select),
          deselect: bind(this, this.deselect),

          onOpen: bind(this, this._onOpenWrapper),
          onClose: bind(this, this._onCloseWrapper),
          onInput: bind(this, this._onInput),
          onClearSelection: bind(this, this._onClearSelection),
          onHover: bind(this, this._onHover),
          onKeydown: bind(this, this._onKeydownWrapper)
        })
      );
    },

    _modifyComponentForRowWrapper(collection, item) {
      let component = this.modifyComponentForRow(collection, item);
      return component || "select-kit/select-kit-row";
    },

    modifyComponentForRow() {},

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
    },

    modifyContentForCollection() {},

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
    },

    modifyComponentForCollection() {},

    didUpdateAttrs() {
      this._super(...arguments);

      this.set("selectKit.isDisabled", this.isDisabled || false);

      this.handleDeprecations();
    },

    willDestroyElement() {
      this._super(...arguments);

      this._searchPromise && cancel(this._searchPromise);

      if (this.popper) {
        this.popper.destroy();
        this.popper = null;
      }
    },

    didReceiveAttrs() {
      this._super(...arguments);

      const computedOptions = {};
      Object.keys(this.selectKitOptions).forEach(key => {
        const value = this.selectKitOptions[key];

        if (
          key === "componentForRow" ||
          key === "contentForCollection" ||
          key === "componentForCollection"
        ) {
          if (typeof value === "string") {
            computedOptions[key] = () => value;
          } else {
            computedOptions[key] = bind(this, value);
          }

          return;
        }

        if (
          typeof value === "string" &&
          value.indexOf(".") < 0 &&
          value in this
        ) {
          const computedValue = get(this, value);
          if (typeof computedValue !== "function") {
            computedOptions[key] = get(this, value);
            return;
          }
        }
        computedOptions[key] = value;
      });
      this.selectKit.options.setProperties(
        Object.assign(computedOptions, this.options || {})
      );

      this.selectKit.setProperties({
        hasSelection: !isEmpty(this.value),
        noneItem: this._modifyNoSelectionWrapper(),
        newItem: null
      });

      if (this.selectKit.isExpanded) {
        if (this._searchPromise) {
          cancel(this._searchPromise);
        }
        this._searchPromise = this._searchWrapper(this.selectKit.filter);
      }

      if (this.computeContent) {
        this._deprecated(
          `The \`computeContent()\` function is deprecated pass a \`content\` attribute or define a \`content\` computed property in your component.`
        );

        this.set("content", this.computeContent());
      }
    },

    selectKitOptions: {
      showFullTitle: true,
      none: null,
      translatedNone: null,
      filterable: false,
      autoFilterable: "autoFilterable",
      filterIcon: "search",
      filterPlaceholder: "filterPlaceholder",
      translatedfilterPlaceholder: null,
      icon: null,
      icons: null,
      maximum: null,
      maximumLabel: null,
      minimum: null,
      minimumLabel: null,
      autoInsertNoneItem: true,
      clearOnClick: false,
      closeOnChange: true,
      limitMatches: null,
      placement: "bottom-start",
      filterComponent: "select-kit/select-kit-filter",
      selectedNameComponent: "selected-name"
    },

    autoFilterable: computed("content.[]", "selectKit.filter", function() {
      return (
        this.selectKit.filter &&
        this.options.autoFilterable &&
        this.content.length > 15
      );
    }),

    filterPlaceholder: computed("options.allowAny", function() {
      return this.options.allowAny
        ? "select_kit.filter_placeholder_with_any"
        : "select_kit.filter_placeholder";
    }),

    collections: computed(
      "selectedContent.[]",
      "mainCollection.[]",
      "errorsCollection.[]",
      function() {
        return this._collections.map(identifier => {
          return {
            identifier,
            content: this.selectKit.modifyContentForCollection(identifier)
          };
        });
      }
    ),

    createContentFromInput(input) {
      return input;
    },

    validateCreate(filter, content) {
      this.clearErrors();

      return (
        filter.length > 0 &&
        content &&
        !content.map(c => this.getValue(c)).includes(filter) &&
        !makeArray(this.value).includes(filter)
      );
    },

    validateSelect() {
      this.clearErrors();

      const selection = Ember.makeArray(this.value);

      const maximum = this.selectKit.options.maximum;
      if (maximum && selection.length >= maximum) {
        const key =
          this.selectKit.options.maximumLabel ||
          "select_kit.max_content_reached";
        this.addError(I18n.t(key, { count: maximum }));
        return false;
      }

      return true;
    },

    addError(error) {
      this.errorsCollection.pushObject(error);

      this._safeAfterRender(() => this.popper && this.popper.update());
    },

    clearErrors() {
      if (!this.element || this.isDestroyed || this.isDestroying) {
        return;
      }

      this.set("errorsCollection", []);
    },

    prependCollection(identifier) {
      this._collections.unshift(identifier);
    },

    appendCollection(identifier) {
      this._collections.push(identifier);
    },

    insertCollectionAtIndex(identifier, index) {
      this._collections.insertAt(index, identifier);
    },

    insertBeforeCollection(identifier, insertedIdentifier) {
      const index = this._collections.indexOf(identifier);
      this.insertCollectionAtIndex(insertedIdentifier, index - 1);
    },

    insertAfterCollection(identifier, insertedIdentifier) {
      const index = this._collections.indexOf(identifier);
      this.insertCollectionAtIndex(insertedIdentifier, index + 1);
    },

    _onInput(event) {
      this.popper && this.popper.update();

      if (this._searchPromise) {
        cancel(this._searchPromise);
      }

      const input = applyOnInputPluginApiCallbacks(
        this.pluginApiIdentifiers,
        event,
        this.selectKit
      );

      if (input) {
        this.selectKit.set("isLoading", true);
        debounce(this, this._debouncedInput, event.target.value, 200);
      }
    },

    _debouncedInput(filter) {
      this.selectKit.set("filter", filter);
      this._searchPromise = this._searchWrapper(filter);
    },

    _onChangeWrapper(value, items) {
      this.selectKit.set("filter", null);

      return new Promise(resolve => {
        if (
          !this.selectKit.valueProperty &&
          this.selectKit.noneItem === value
        ) {
          value = null;
          items = [];
        }

        this._boundaryActionHandler("onChange", value, items);
        resolve(items);
      }).finally(() => {
        if (!this.isDestroying && !this.isDestroyed) {
          if (this.selectKit.options.closeOnChange) {
            this.selectKit.close();
          }

          this._safeAfterRender(() => {
            this._focusFilter();
            this.popper && this.popper.update();
          });
        }
      });
    },

    _modifyContentWrapper(content) {
      content = this.modifyContent(content);

      return applyContentPluginApiCallbacks(
        this.pluginApiIdentifiers,
        content,
        this.selectKit
      );
    },

    modifyContent(content) {
      return content;
    },

    _modifyNoSelectionWrapper() {
      let none = this.modifyNoSelection();

      return applyModifyNoSelectionPluginApiCallbacks(
        this.pluginApiIdentifiers,
        none,
        this.selectKit
      );
    },

    modifyNoSelection() {
      if (this.selectKit.options.translatedNone) {
        return this.defaultItem(null, this.selectKit.options.translatedNone);
      }

      let none = this.selectKit.options.none;
      if (isNone(none) && !this.selectKit.options.allowAny) return null;

      if (
        isNone(none) &&
        this.selectKit.options.allowAny &&
        !this.selectKit.isExpanded
      ) {
        return this.defaultItem(
          null,
          I18n.t("select_kit.filter_placeholder_with_any")
        );
      }

      let item;
      switch (typeof none) {
        case "string":
          item = this.defaultItem(null, I18n.t(none));
          break;
        default:
          item = none;
      }

      return item;
    },

    _modifySelectionWrapper(item) {
      applyHeaderContentPluginApiCallbacks(
        this.pluginApiIdentifiers,
        item,
        this.selectKit
      );

      return this.modifySelection(item);
    },

    modifySelection(item) {
      return item;
    },

    _onKeydownWrapper(event) {
      return this._boundaryActionHandler("onKeydown", event);
    },

    _onHover(value, item) {
      throttle(this, this._highlight, item, 25, true);
    },

    _highlight(item) {
      this.selectKit.set("highlighted", item);
    },

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
    },

    deselect() {
      this.clearErrors();
      this.selectKit.change(null, null);
    },

    search(filter) {
      let content = this.content || [];
      if (filter) {
        filter = this._normalize(filter);
        content = content.filter(c => {
          const name = this._normalize(this.getName(c));
          return name && name.indexOf(filter) > -1;
        });
      }
      return content;
    },

    _searchWrapper(filter) {
      this.clearErrors();
      this.setProperties({ mainCollection: [], "selectKit.isLoading": true });
      this._safeAfterRender(() => this.popper && this.popper.update());

      let content = [];

      return Promise.resolve(this.search(filter)).then(result => {
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
              : this.mainCollection.firstObject,
          isLoading: false,
          hasNoContent
        });

        this._safeAfterRender(() => {
          this.popper && this.popper.update();
          this._focusFilter();
        });
      });
    },

    _safeAfterRender(fn) {
      next(() => {
        schedule("afterRender", () => {
          if (!this.element || this.isDestroyed || this.isDestroying) {
            return;
          }

          fn();
        });
      });
    },

    _scrollToRow(rowItem) {
      const value = this.getValue(rowItem);
      const rowContainer = this.element.querySelector(
        `.select-kit-row[data-value="${value}"]`
      );

      if (rowContainer) {
        const $collection = $(
          this.element.querySelector(".select-kit-collection")
        );

        const collectionTop = $collection.position().top;

        $collection.scrollTop(
          $collection.scrollTop() +
            $(rowContainer).position().top -
            collectionTop
        );
      }
    },

    _highlightNext() {
      const highlightedIndex = this.mainCollection.indexOf(
        this.selectKit.highlighted
      );
      let newHighlightedIndex = highlightedIndex;
      const count = this.mainCollection.length;

      if (highlightedIndex < count - 1) {
        newHighlightedIndex = highlightedIndex + 1;
      } else {
        newHighlightedIndex = 0;
      }

      const highlighted = this.mainCollection.objectAt(newHighlightedIndex);
      if (highlighted) {
        this._scrollToRow(highlighted);
        this.set("selectKit.highlighted", highlighted);
      }
    },

    _highlightPrevious() {
      const highlightedIndex = this.mainCollection.indexOf(
        this.selectKit.highlighted
      );
      let newHighlightedIndex = highlightedIndex;
      const count = this.mainCollection.length;

      if (highlightedIndex > 0) {
        newHighlightedIndex = highlightedIndex - 1;
      } else {
        newHighlightedIndex = count - 1;
      }

      const highlighted = this.mainCollection.objectAt(newHighlightedIndex);
      if (highlighted) {
        this._scrollToRow(highlighted);
        this.set("selectKit.highlighted", highlighted);
      }
    },

    select(value, item) {
      if (!value) {
        if (!this.validateSelect(this.selectKit.highlighted)) {
          return;
        }

        this.selectKit.change(
          this.getValue(this.selectKit.highlighted),
          this.selectKit.highlighted
        );
      } else {
        const existingItem = this.findValue(this.mainCollection, item);
        if (existingItem) {
          if (!this.validateSelect(item)) {
            return;
          }
        }

        this.selectKit.change(value, item || this.defaultItem(value, value));
      }
    },

    _onClearSelection() {
      this.selectKit.change(null, null);
    },

    _onOpenWrapper(event) {
      let boundaryAction = this._boundaryActionHandler("onOpen");

      boundaryAction = applyOnOpenPluginApiCallbacks(
        this.pluginApiIdentifiers,
        this.selectKit,
        event
      );

      return boundaryAction;
    },

    _onCloseWrapper(event) {
      this._focusFilter(this.multiSelect);

      this.set("selectKit.highlighted", null);

      let boundaryAction = this._boundaryActionHandler("onClose");

      boundaryAction = applyOnClosePluginApiCallbacks(
        this.pluginApiIdentifiers,
        this.selectKit,
        event
      );

      return boundaryAction;
    },

    _toggle(event) {
      if (this.selectKit.isExpanded) {
        this._close(event);
      } else {
        this._open(event);
      }
    },

    _close(event) {
      if (!this.selectKit.isExpanded) {
        return;
      }

      this.clearErrors();

      if (!this.selectKit.onClose(event)) {
        return;
      }

      this.selectKit.setProperties({
        isExpanded: false,
        filter: null
      });
    },

    _open(event) {
      if (this.selectKit.isExpanded) {
        return;
      }

      this.clearErrors();

      if (!this.selectKit.onOpen(event)) {
        return;
      }

      if (!this.popper) {
        const anchor = document.querySelector(
          `[data-select-kit-id=${this.selectKit.uniqueID}-header]`
        );
        const popper = document.querySelector(
          `[data-select-kit-id=${this.selectKit.uniqueID}-body]`
        );

        if (
          this.site &&
          !this.site.mobileView &&
          popper.offsetWidth < anchor.offsetWidth
        ) {
          popper.style.minWidth = `${anchor.offsetWidth}px`;
        }

        const inModal = $(this.element).parents("#discourse-modal").length;

        if (this.site && !this.site.mobileView && inModal) {
          popper.style.width = `${anchor.offsetWidth}px`;
        }

        /* global Popper:true */
        this.popper = Popper.createPopper(anchor, popper, {
          eventsEnabled: false,
          strategy: inModal ? "fixed" : "absolute",
          placement: this.selectKit.options.placement,
          modifiers: [
            {
              name: "positionWrapper",
              phase: "afterWrite",
              enabled: true,
              fn: data => {
                const wrapper = this.element.querySelector(
                  ".select-kit-wrapper"
                );
                if (wrapper) {
                  let height = this.element.offsetHeight;

                  const body = this.element.querySelector(".select-kit-body");
                  if (body) {
                    height += body.offsetHeight;
                  }

                  const popperElement = data.state.elements.popper;
                  if (
                    popperElement &&
                    popperElement.getAttribute("data-popper-placement") ===
                      "top-start"
                  ) {
                    this.element.classList.remove("is-under");
                    this.element.classList.add("is-above");
                  } else {
                    this.element.classList.remove("is-above");
                    this.element.classList.add("is-under");
                  }

                  wrapper.style.width = `${this.element.offsetWidth}px`;
                  wrapper.style.height = `${height}px`;
                }
              }
            }
          ]
        });
      }

      this.selectKit.setProperties({
        isExpanded: true,
        isFilterExpanded:
          this.selectKit.options.filterable || this.selectKit.options.allowAny
      });

      if (this._searchPromise) {
        cancel(this._searchPromise);
      }
      this._searchPromise = this._searchWrapper();

      this._safeAfterRender(() => {
        this._focusFilter();
        this.popper && this.popper.update();
      });
    },

    _focusFilter(forceHeader = false) {
      this._safeAfterRender(() => {
        const input = this.getFilterInput();
        if (!forceHeader && input) {
          input.focus({ preventScroll: true });
        } else {
          const headerContainer = this.getHeader();
          headerContainer && headerContainer.focus({ preventScroll: true });
        }
      });
    },

    getFilterInput() {
      return document.querySelector(
        `[data-select-kit-id=${this.selectKit.uniqueID}-filter] input`
      );
    },

    getHeader() {
      return document.querySelector(
        `[data-select-kit-id=${this.selectKit.uniqueID}-header]`
      );
    },

    handleDeprecations() {
      this._deprecateValueAttribute();
      this._deprecateMutations();
      this._deprecateOptions();
    },

    _deprecated(text) {
      const discourseSetup = document.getElementById("data-discourse-setup");
      if (
        discourseSetup &&
        discourseSetup.getAttribute("data-environment") === "development"
      ) {
        deprecated(text, { since: "v2.4.0" });
      }
    },

    _deprecateValueAttribute() {
      if (this.valueAttribute || this.valueAttribute === null) {
        this._deprecated(
          "The `valueAttribute` is deprecated. Use `valueProperty` instead"
        );

        this.set("valueProperty", this.valueAttribute);
      }
    },

    _deprecateMutations() {
      this.actions = this.actions || {};
      this.attrs = this.attrs || {};

      if (!this.attrs.onChange && !this.actions.onChange) {
        this._deprecated(
          "Implicit mutation has been deprecated, please use `onChange` handler"
        );

        this.actions.onChange =
          this.attrs.onSelect ||
          this.actions.onSelect ||
          (value => this.set("value", value));
      }
    },

    _deprecateOptions() {
      const migrations = {
        headerIcon: "icon",
        onExpand: "onOpen",
        onCollapse: "onClose",
        allowAny: "options.allowAny",
        allowCreate: "options.allowAny",
        filterable: "options.filterable",
        excludeCategoryId: "options.excludeCategoryId",
        scopedCategoryId: "options.scopedCategoryId",
        allowUncategorized: "options.allowUncategorized",
        none: "options.none",
        rootNone: "options.none",
        isDisabled: "options.isDisabled",
        rootNoneLabel: "options.none",
        showFullTitle: "options.showFullTitle",
        title: "options.translatedNone",
        maximum: "options.maximum",
        minimum: "options.minimum",
        i18nPostfix: "options.i18nPostfix",
        i18nPrefix: "options.i18nPrefix"
      };

      Object.keys(migrations).forEach(from => {
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
);
