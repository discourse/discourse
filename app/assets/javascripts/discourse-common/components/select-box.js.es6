import { on, observes } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  layoutName: "discourse-common/templates/components/select-box",
  classNames: "select-box",
  classNameBindings: [
    "isExpanded",
    "isDisabled",
    "isHidden",
    "isAbove",
    "isBelow",
    "isLeftAligned",
    "isRightAligned"
  ],

  isDisabled: false,
  isExpanded: false,
  focused: false,
  filterFocused: false,
  renderBody: false,
  wrapper: true,
  isHidden: false,
  tabindex: 0,
  scrollableParentSelector: ".modal-body",

  caretUpIcon: "caret-up",
  caretDownIcon: "caret-down",
  headerPlacerholder: "select_box.default_header_text",
  dynamicHeader: true,
  icon: null,

  @computed("selectedContents")
  headerText(selectedContents) {
    if (!Ember.isNone(this.get("none")) && Ember.isEmpty(selectedContents)) {
      return this._localizeNone(this.get("none"));
    } else {
      return this.textForContent(selectedContents[0]);
    }
  },

  _localizeNone(none) {
    switch (typeof none){
    case "string":
      return I18n.t(none);
    default:
      return I18n.t(this.textForContent(none));
    }
  },

  value: null,
  valueIds: [],
  highlightedValue: null,
  selectedContent: null,
  noContentLabel: I18n.t("select_box.no_content"),
  none: null,

  valueAttribute: "id",
  nameProperty: "name",
  iconKey: "icon",

  filterable: false,
  filter: "",
  filterPlaceholder: I18n.t("select_box.filter_placeholder"),
  filterIcon: "search",

  selectBoxRowComponent: "select-box/select-box-row",
  selectBoxFilterComponent: "select-box/select-box-filter",
  selectBoxHeaderComponent: "select-box/select-box-header",
  selectBoxCollectionComponent: "select-box/select-box-collection",

  collectionHeight: 200,
  verticalOffset: 0,
  horizontalOffset: 0,
  fullWidthOnMobile: false,

  castInteger: false,

  click(event) {
    event.stopPropagation();
  },

  @computed("selectedContents")
  selectedContentsIds(selectedContents) {
    return selectedContents.map((v) => this.valueForContent(v) );
  },

  @observes("value")
  @on("didReceiveAttrs")
  _valueChanged() {
    const content = this.get("content");
    const value = this.get("value");
    const none = this.get("none");

    if (!Ember.isNone(none) && Ember.isNone(value)) {
      this.set("selectedContents", []);
      return;
    }

    if (Ember.isNone(value) && !Ember.isEmpty(content)) {
      this.set("selectedContents", [ content[0] ]);
      return;
    }

    this.set("selectedContents", [ value ]);
  },

  filterFunction: function(content) {
    return (selectBox) => {
      const filter = selectBox.get("filter").toLowerCase();
      return _.filter(content, (c) => {
        return this.textForContent(c, selectBox.get("nameProperty"))
                   .toLowerCase()
                   .indexOf(filter) > -1;
      });
    };
  },

  @computed("nameProperty")
  titleForRow(nameProperty) {
    return (rowComponent) => {
      return this.textForContent(rowComponent.get("content"), nameProperty)
    };
  },

  @computed("valueAttribute")
  idForRow(valueAttribute) {
    return (rowComponent) => {
      return this.valueForContent(rowComponent.get("content"), valueAttribute);
    };
  },

  @computed
  shouldHighlightRow: function() {
    return (rowComponent) => {
      const id = this.valueForContent(rowComponent.get("content"));
      return id === this.get("highlightedValue");
    };
  },

  @computed("value", "valueAttribute")
  shouldSelectRow(value, valueAttribute) {
    return (rowComponent) => {
      const id = this.valueForContent(rowComponent.get("content"), valueAttribute);
      return id === value;
    };
  },

  textForContent(content, nameProperty) {
    if (Ember.isNone(content)) {
      return null;
    }

    nameProperty = nameProperty || this.get("nameProperty");

    switch (typeof content) {
    case "string":
      return content;
    default:
      return Ember.get(content, nameProperty);
    }
  },


  valueForContent(content, valueAttribute) {
    valueAttribute = valueAttribute || this.get("valueAttribute");

    switch (typeof content){
    case "string":
      return this._castInteger(content);
    default:
      return this._castInteger(Ember.get(content, valueAttribute));
    }
  },

  @computed
  templateForRow() {
    return (rowComponent) => {
      let template = "";

      const icon = rowComponent.icon();
      if (icon) {
        template += icon;
      }

      const text = this.textForContent(rowComponent.get("content"));
      template += `<p class="text">${Handlebars.escapeExpression(text)}</p>`;

      return template;
    };
  },

  applyDirection() {
    let options = { left: "auto", bottom: "auto", left: "auto", top: "auto" };
    const headerHeight = this.$(".select-box-header").outerHeight(false);
    const filterHeight = this.$(".select-box-filter").outerHeight(false);
    const bodyHeight = this.$(".select-box-body").outerHeight(false);
    const windowWidth = $(window).width();
    const windowHeight = $(window).height();
    const boundingRect = this.$()[0].getBoundingClientRect();
    const offsetTop = boundingRect.top;

    if (this.get("fullWidthOnMobile") && windowWidth <= 420) {
      const margin = 10;
      const relativeLeft = this.$().offset().left - $(window).scrollLeft();
      options.left = margin - relativeLeft;
      options.width = windowWidth - margin * 2;
      options.maxWidth = options.minWidth = "unset";
    } else {
      const offsetLeft = boundingRect.left;
      const bodyWidth = this.$(".select-box-body").outerWidth(false);
      const hasRightSpace = (windowWidth - (this.get("horizontalOffset") + offsetLeft + filterHeight + bodyWidth) > 0);

      if (hasRightSpace) {
        this.setProperties({ isLeftAligned: true, isRightAligned: false })
        options.left = this.get("horizontalOffset");
      } else {
        this.setProperties({ isLeftAligned: false, isRightAligned: true })
        options.right = this.get("horizontalOffset");
      }
    }

    const componentHeight = this.get("verticalOffset") + bodyHeight + headerHeight;
    const hasBelowSpace = windowHeight - offsetTop - componentHeight > 0;
    if (hasBelowSpace) {
      this.setProperties({ isBelow: true, isAbove: false })
      options.top = headerHeight + this.get("verticalOffset");
    } else {
      this.setProperties({ isBelow: false, isAbove: true })
      options.bottom = headerHeight + this.get("verticalOffset");
    }

    this.$(".select-box-body").css(options);
  },

  init() {
    this._super();

    if ($(window).outerWidth(false) <= 420) {
      this.set("filterable", false);
    }

    this.setProperties({
      content: this.getWithDefault("content", []),
      componentId: this.elementId
    });
  },

  @on("willDestroyElement")
  _removeDocumentListeners: function() {
    $(document).off("click.select-box");
    $(window).off("resize.select-box");
  },

  @on("willDestroyElement")
  _unbindEvents() {
    this.$(".select-box-offscreen").off(
      "focusin.select-box",
      "focusout.select-box",
      "keydown.select-box"
    );
    this.$(".filter-query").off("focusin.select-box", "focusout.select-box");
  },

  @on("didRender")
  _configureSelectBoxDOM: function() {
    if (this.get("scrollableParent").length === 1) {
      this._removeFixedPosition();
    }

    const computedWidth = this.$().outerWidth(false);
    const computedHeight = this.$().outerHeight(false);

    if (this.get("isExpanded")) {
      if (this.get("scrollableParent").length === 1) {
        this._applyFixedPosition(computedWidth, computedHeight);
      }

      this.$(".select-box-collection").css("max-height", this.get("collectionHeight"));

      Ember.run.schedule("afterRender", () => {
        this.applyDirection();
        this._positionSelectBoxWrapper();
      });
    } else {
      this.$(".select-box-wrapper").hide();
    }
  },

  keyDown(event) {
    const keyCode = event.keyCode || event.which;

    if (this.get("isExpanded")) {
      if ((keyCode === 13 || keyCode === 9) && Ember.isPresent(this.get("highlightedValue"))) {
        event.preventDefault();
        this.send("onSelectRow", this.get("highlightedContent"));
      }

      if (keyCode === 9) {
        this.set("isExpanded", false);
      }

      if (keyCode === 27) {
        this.set("isExpanded", false);
        event.stopPropagation();
      }

      if (keyCode === 38) {
        event.preventDefault();
        const self = this;
        Ember.run.throttle(self, this._handleUpArrow, 50);
      }

      if (keyCode === 40) {
        event.preventDefault();
        const self = this;
        Ember.run.throttle(self, this._handleDownArrow, 50);
      }
    }
  },

  @on("didRender")
  _setupDocumentListeners: function() {
    $(document)
      .off("click.select-box")
      .on("click.select-box", (event) => {
        if (this.isDestroying || this.isDestroyed) { return; }

        if (!$(event.target).closest(this.$()).length) {
          this.set("isExpanded", false);
        }
      });

    $(window).on("resize.select-box", () => this.set("isExpanded", false) );
  },

  @on("didInsertElement")
  _bindEvents() {
    this.$(".select-box-offscreen")
      .on("focusin.select-box", () => this.set("focused", true) )
      .on("focusout.select-box", () => this.set("focused", false) );

    this.$(".filter-query")
      .on("focusin.select-box", () => this.set("filterFocused", true) )
      .on("focusout.select-box", () => this.set("filterFocused", false) );

    this.$(".select-box-offscreen").on("keydown.select-box", (event) => {
      const keyCode = event.keyCode || event.which;

      if (keyCode === 13 || keyCode === 40) {
        this.setProperties({ isExpanded: true, focused: false });
        event.stopPropagation();
      }

      if (keyCode >= 65 && keyCode <= 90) {
        this.setProperties({ isExpanded: true, focused: false });
        Ember.run.schedule("afterRender", () => {
          this.$(".filter-query").focus().val(String.fromCharCode(keyCode));
        });
      }
    });
  },

  @observes("isExpanded")
  _isExpandedChanged() {
    if (this.get("isExpanded")) {
      this.setProperties({ highlightedValue: null, renderBody: true, focused: false });

      if (this.get("filterable")) {
        Ember.run.schedule("afterRender", () => this.$(".filter-query").focus());
      }
    };
  },

  @computed("value", "content.[]", "valueAttribute")
  selectedContent(value, contents, valueAttribute) {
    if (Ember.isNone(value)) {
      return null;
    }

    return contents.find((content) => {
      return this.valueForContent(content, valueAttribute) === value;
    });
  },

  @computed("highlightedValue", "content.[]", "valueAttribute")
  highlightedContent(highlightedValue, contents, valueAttribute) {
    if (Ember.isNone(highlightedValue)) {
      return null;
    }

    return contents.find((content) => {
      return this.valueForContent(content, valueAttribute) === highlightedValue;
    });
  },

  @computed("none")
  clearSelectionLabel(none) {
    if(Ember.isNone(none)) {
      return null;
    }

    switch (typeof none){
    case "string":
      return I18n.t(none);
    default:
      return this.textForContent(none);
    }
  },

  @computed("content.[]", "filter", "valueAttribute")
  filteredContent(content, filter, valueAttribute) {
    let filteredContent;

    if (Ember.isEmpty(filter)) {
      filteredContent = content;
    } else {
      filteredContent = this.filterFunction(content)(this);

      if (!Ember.isEmpty(filteredContent)) {
        this.set("highlightedValue", filteredContent[0][valueAttribute]);
      }
    }

    return filteredContent;
  },

  @computed("scrollableParentSelector")
  scrollableParent(scrollableParentSelector) {
    return this.$().parents(scrollableParentSelector).first();
  },

  actions: {
    onToggle() {
      this.toggleProperty("isExpanded");
    },

    onFilterChange(filter) {
      this.set("filter", filter);
    },

    onHoverRow(content) {
      const id = this.valueForContent(content);
      this.set("highlightedValue", id);
    },

    onSelectRow() {
      this.setProperties({ isExpanded: false, filter: "" });
    },

    onDeselectContent() {},

    onClearSelection() {
      this.setProperties({ value: null, isExpanded: false });
    }
  },

  _positionSelectBoxWrapper() {
    const headerHeight = this.$(".select-box-header").outerHeight(false);

    this.$(".select-box-wrapper").css({
      width: this.$().width(),
      display: "block",
      height: headerHeight + this.$(".select-box-body").outerHeight(false)
    });
  },

  _castInteger(id) {
    if (this.get("castInteger") === true && Ember.isPresent(id)) {
      return parseInt(id, 10);
    }

    return id;
  },

  _applyFixedPosition(width, height) {
    const $placeholder = $(`<div class='select-box-fixed-placeholder-${this.get("componentId")}' style='vertical-align: middle; height: ${height}px; width: ${width}px; line-height: ${height}px;display:inline-block'></div>`);

    this.$()
      .before($placeholder)
      .css({
        width,
        position: "fixed",
        "margin-top": -this.get("scrollableParent").scrollTop(),
        "margin-left": -width
      });

    this.get("scrollableParent").on("scroll.select-box", () => this.set("isExpanded", false) );
  },

  _removeFixedPosition() {
    $(`.select-box-fixed-placeholder-${this.get("componentId")}`).remove();
    this.$().css({
      top: "auto",
      left: "auto",
      "margin-left": "auto",
      "margin-top": "auto",
      position: "relative"
    });

    this.get("scrollableParent").off("scroll.select-box");
  },

  _handleDownArrow() {
    this._handleArrow("down");
  },

  _handleUpArrow() {
    this._handleArrow("up");
  },

  _handleArrow(direction) {
    const content = this.get("filteredContent");
    const valueAttribute = this.get("valueAttribute");
    const selectedContent = content.findBy(valueAttribute, this.get("highlightedValue"));
    const currentIndex = content.indexOf(selectedContent);

    if (direction === "down") {
      if (currentIndex < 0) {
        this.set("highlightedValue", this._castInteger(Ember.get(content[0], valueAttribute)));
      } else if(currentIndex + 1 < content.length) {
        this.set("highlightedValue", this._castInteger(Ember.get(content[currentIndex + 1], valueAttribute)));
      }
    } else {
      if (currentIndex <= 0) {
        this.set("highlightedValue", this._castInteger(Ember.get(content[0], valueAttribute)));
      } else if(currentIndex - 1 < content.length) {
        this.set("highlightedValue", this._castInteger(Ember.get(content[currentIndex - 1], valueAttribute)));
      }
    }

    Ember.run.schedule("afterRender", () => {
      const $highlightedRow = this.$(".select-box-row.is-highlighted");

      if ($highlightedRow.length === 0) { return; }

      const $collection = this.$(".select-box-collection");
      const rowOffset = $highlightedRow.offset();
      const bodyOffset = $collection.offset();
      $collection.scrollTop(rowOffset.top - bodyOffset.top);
    });
  }
});
