const { get, isNone, run, isEmpty, makeArray } = Ember;
import computed from "ember-addons/ember-computed-decorators";
import UtilsMixin from "select-kit/mixins/utils";
import DomHelpersMixin from "select-kit/mixins/dom-helpers";
import EventsMixin from "select-kit/mixins/events";
import PluginApiMixin from "select-kit/mixins/plugin-api";
import {
  applyContentPluginApiCallbacks,
  applyHeaderContentPluginApiCallbacks,
  applyCollectionHeaderCallbacks
} from "select-kit/mixins/plugin-api";

export default Ember.Component.extend(
  UtilsMixin,
  PluginApiMixin,
  DomHelpersMixin,
  EventsMixin,
  {
    pluginApiIdentifiers: ["select-kit"],
    layoutName: "select-kit/templates/components/select-kit",
    classNames: ["select-kit"],
    classNameBindings: [
      "isLoading",
      "isFocused",
      "isExpanded",
      "isDisabled",
      "isHidden",
      "hasSelection",
      "hasReachedMaximum",
      "hasReachedMinimum"
    ],
    isDisabled: false,
    isExpanded: false,
    isFocused: false,
    isHidden: false,
    isLoading: false,
    isAsync: false,
    renderedBodyOnce: false,
    renderedFilterOnce: false,
    tabindex: 0,
    none: null,
    highlighted: null,
    valueAttribute: "id",
    nameProperty: "name",
    autoFilterable: false,
    filterable: false,
    filter: "",
    previousFilter: "",
    filterIcon: "search",
    headerIcon: null,
    rowComponent: "select-kit/select-kit-row",
    rowComponentOptions: null,
    noneRowComponent: "select-kit/select-kit-none-row",
    createRowComponent: "select-kit/select-kit-create-row",
    filterComponent: "select-kit/select-kit-filter",
    headerComponent: "select-kit/select-kit-header",
    headerComponentOptions: null,
    headerComputedContent: null,
    collectionHeaderComputedContent: null,
    collectionComponent: "select-kit/select-kit-collection",
    verticalOffset: 0,
    horizontalOffset: 0,
    fullWidthOnMobile: false,
    castInteger: false,
    castBoolean: false,
    allowAny: false,
    allowInitialValueMutation: false,
    content: null,
    computedContent: null,
    limitMatches: null,
    nameChanges: false,
    allowContentReplacement: false,
    collectionHeader: null,
    allowAutoSelectFirst: true,
    highlightedSelection: null,
    maximum: null,
    minimum: null,
    minimumLabel: null,
    maximumLabel: null,
    forceEscape: false,

    init() {
      this._super(...arguments);

      this.selectKitComponent = true;
      this.noneValue = "__none__";
      this.set(
        "headerComponentOptions",
        Ember.Object.create({ forceEscape: this.get("forceEscape") })
      );
      this.set(
        "rowComponentOptions",
        Ember.Object.create({
          forceEscape: this.get("forceEscape")
        })
      );
      this.set("computedContent", []);
      this.set("highlightedSelection", []);

      if (this.get("nameChanges")) {
        this.addObserver(
          `content.@each.${this.get("nameProperty")}`,
          this,
          this._compute
        );
      }

      if (this.get("allowContentReplacement")) {
        this.addObserver(`content.[]`, this, this._compute);
      }

      if (this.get("isAsync")) {
        this.addObserver(`asyncContent.[]`, this, this._compute);
      }
    },

    keyDown(event) {
      if (!isEmpty(this.get("filter"))) return true;

      const keyCode = event.keyCode || event.which;

      if (event.metaKey === true && keyCode === this.keys.A) {
        this.didPressSelectAll();
        return false;
      }

      if (keyCode === this.keys.BACKSPACE) {
        this.didPressBackspace();
        return false;
      }
    },

    willDestroyElement() {
      this.removeObserver(
        `content.@each.${this.get("nameProperty")}`,
        this,
        this._compute
      );
      this.removeObserver(`content.[]`, this, this._compute);
      this.removeObserver(`asyncContent.[]`, this, this._compute);
    },

    willComputeAttributes() {},
    didComputeAttributes() {},

    willComputeContent(content) {
      return content;
    },
    computeContent(content) {
      return content;
    },
    _beforeDidComputeContent(content) {
      content = applyContentPluginApiCallbacks(
        this.get("pluginApiIdentifiers"),
        content,
        this
      );

      let existingCreatedComputedContent = [];
      if (!this.get("allowContentReplacement")) {
        existingCreatedComputedContent = this.get("computedContent").filterBy(
          "created",
          true
        );
      }

      this.setProperties({
        computedContent: content
          .map(c => this.computeContentItem(c))
          .concat(existingCreatedComputedContent)
      });
      return content;
    },
    didComputeContent() {},

    willComputeAsyncContent(content) {
      return content;
    },
    computeAsyncContent(content) {
      return content;
    },
    _beforeDidComputeAsyncContent(content) {
      content = applyContentPluginApiCallbacks(
        this.get("pluginApiIdentifiers"),
        content,
        this
      );
      this.setProperties({
        computedAsyncContent: content.map(c => this.computeAsyncContentItem(c))
      });
      return content;
    },
    didComputeAsyncContent() {},

    computeContentItem(contentItem, options) {
      let originalContent;
      options = options || {};
      const name = options.name;

      if (typeof contentItem === "string" || typeof contentItem === "number") {
        originalContent = {};
        originalContent[this.get("valueAttribute")] = contentItem;
        originalContent[this.get("nameProperty")] = name || contentItem;
      } else {
        originalContent = contentItem;
      }

      let computedContentItem = {
        value: this._cast(this.valueForContentItem(contentItem)),
        name: name || this._nameForContent(contentItem),
        locked: false,
        created: options.created || false,
        __sk_row_type: options.created
          ? "createRow"
          : contentItem.__sk_row_type,
        originalContent
      };

      return computedContentItem;
    },

    computeAsyncContentItem(contentItem, options) {
      return this.computeContentItem(contentItem, options);
    },

    @computed(
      "isAsync",
      "isLoading",
      "filteredAsyncComputedContent.[]",
      "filteredComputedContent.[]"
    )
    collectionComputedContent(
      isAsync,
      isLoading,
      filteredAsyncComputedContent,
      filteredComputedContent
    ) {
      if (isAsync) {
        return isLoading ? [] : filteredAsyncComputedContent;
      } else {
        return filteredComputedContent;
      }
    },

    validateCreate(created) {
      return !this.get("hasReachedMaximum") && created.length > 0;
    },

    validateSelect() {
      return !this.get("hasReachedMaximum");
    },

    @computed("maximum", "selection.[]")
    hasReachedMaximum(maximum, selection) {
      if (!maximum) return false;
      selection = makeArray(selection);
      return selection.length >= maximum;
    },

    @computed("minimum", "selection.[]")
    hasReachedMinimum(minimum, selection) {
      if (!minimum) return true;
      selection = makeArray(selection);
      return selection.length >= minimum;
    },

    @computed("shouldFilter", "allowAny")
    shouldDisplayFilter(shouldFilter, allowAny) {
      if (shouldFilter) return true;
      if (allowAny) return true;
      return false;
    },

    @computed("filter", "collectionComputedContent.[]", "isLoading")
    noContentRow(filter, collectionComputedContent, isLoading) {
      if (
        filter.length > 0 &&
        collectionComputedContent.length === 0 &&
        !isLoading
      ) {
        return (
          this.get("termMatchErrorMessage") || I18n.t("select_kit.no_content")
        );
      }
    },

    @computed("hasReachedMaximum", "hasReachedMinimum", "isExpanded")
    validationMessage(hasReachedMaximum, hasReachedMinimum) {
      if (hasReachedMaximum && this.get("maximum")) {
        const key =
          this.get("maximumLabel") || "select_kit.max_content_reached";
        return I18n.t(key, { count: this.get("maximum") });
      }

      if (!hasReachedMinimum && this.get("minimum")) {
        const key =
          this.get("minimumLabel") || "select_kit.min_content_not_reached";
        return I18n.t(key, { count: this.get("minimum") });
      }
    },

    @computed("allowAny")
    filterPlaceholder(allowAny) {
      return allowAny
        ? "select_kit.filter_placeholder_with_any"
        : "select_kit.filter_placeholder";
    },

    @computed("filter", "filterable", "autoFilterable", "renderedFilterOnce")
    shouldFilter(filter, filterable, autoFilterable, renderedFilterOnce) {
      if (renderedFilterOnce && filterable) return true;
      if (filterable) return true;
      if (autoFilterable && filter.length > 0) return true;
      return false;
    },

    @computed(
      "computedValue",
      "filter",
      "collectionComputedContent.[]",
      "hasReachedMaximum",
      "isLoading"
    )
    shouldDisplayCreateRow(
      computedValue,
      filter,
      collectionComputedContent,
      hasReachedMaximum,
      isLoading
    ) {
      if (isLoading || hasReachedMaximum) return false;
      if (collectionComputedContent.map(c => c.value).includes(filter))
        return false;
      if (this.get("allowAny") && this.validateCreate(filter)) return true;
      return false;
    },

    @computed("filter", "shouldDisplayCreateRow")
    createRowComputedContent(filter, shouldDisplayCreateRow) {
      if (shouldDisplayCreateRow) {
        let content = this.createContentFromInput(filter);
        let computedContentItem = this.computeContentItem(content, {
          created: true
        });
        computedContentItem.__sk_row_type = "createRow";
        return computedContentItem;
      }
    },

    @computed
    templateForRow() {
      return () => null;
    },

    @computed
    templateForNoneRow() {
      return () => null;
    },

    @computed("filter")
    templateForCreateRow() {
      return rowComponent => {
        return I18n.t("select_kit.create", {
          content: rowComponent.get("computedContent.name")
        });
      };
    },

    @computed("none")
    noneRowComputedContent(none) {
      if (isNone(none)) return null;

      let noneRowComputedContent;

      switch (typeof none) {
        case "string":
          noneRowComputedContent = this.computeContentItem(this.noneValue, {
            name: (I18n.t(none) || "").htmlSafe()
          });
          break;
        default:
          noneRowComputedContent = this.computeContentItem(none);
      }

      noneRowComputedContent.__sk_row_type = "noneRow";

      return noneRowComputedContent;
    },

    createContentFromInput(input) {
      return input;
    },

    highlightSelection(items) {
      this.set("highlightedSelection", makeArray(items));
      this.notifyPropertyChange("highlightedSelection");
    },

    clearHighlightSelection() {
      this.highlightSelection([]);
    },

    willSelect() {},
    didSelect() {},

    willCreate() {},
    didCreate() {},

    willDeselect() {},
    didDeselect() {},

    clearFilter() {
      this.$filterInput().val("");
      this.setProperties({ filter: "", previousFilter: "" });
    },

    startLoading() {
      this.set("isLoading", true);
      this.set("highlighted", null);
      this._boundaryActionHandler("onStartLoading");
    },

    stopLoading() {
      if (this.site && !this.site.isMobileDevice) {
        this.focusFilterOrHeader();
      }

      this.set("isLoading", false);
      this._boundaryActionHandler("onStopLoading");
    },

    @computed("selection.[]", "isExpanded", "filter", "highlightedSelection.[]")
    collectionHeaderComputedContent() {
      return applyCollectionHeaderCallbacks(
        this.get("pluginApiIdentifiers"),
        this.get("collectionHeader"),
        this
      );
    },

    @computed("selection.[]", "isExpanded", "headerIcon")
    headerComputedContent() {
      return applyHeaderContentPluginApiCallbacks(
        this.get("pluginApiIdentifiers"),
        this.computeHeaderContent(),
        this
      );
    },

    _boundaryActionHandler(actionName, ...params) {
      if (get(this.actions, actionName)) {
        run.next(() => this.send(actionName, ...params));
      } else if (this.get(actionName)) {
        run.next(() => this.get(actionName)(...params));
      }
    },

    highlight(computedContent) {
      this.set("highlighted", computedContent);
      this._boundaryActionHandler("onHighlight", computedContent);
    },

    clearSelection() {
      this.deselect(this.get("selection"));
      this.focusFilterOrHeader();
    },

    actions: {
      onToggle() {
        this.clearHighlightSelection();

        if (this.get("isExpanded")) {
          this.collapse();
        } else {
          this.expand();
        }
      },

      onClickRow(computedContentItem) {
        this.didClickRow(computedContentItem);
      },

      onClickSelectionItem(computedContentItem) {
        this.didClickSelectionItem(computedContentItem);
      },

      onClearSelection() {
        this.clearSelection();
      },

      onMouseoverRow(computedContentItem) {
        this.highlight(computedContentItem);
      },

      onFilterComputedContent(filter) {
        if (filter === this.get("previousFilter")) return;

        this.clearHighlightSelection();

        this.setProperties({
          highlighted: null,
          renderedFilterOnce: true,
          previousFilter: filter,
          filter
        });
        this.autoHighlight();
        this._boundaryActionHandler("onFilter", filter);
      }
    }
  }
);
