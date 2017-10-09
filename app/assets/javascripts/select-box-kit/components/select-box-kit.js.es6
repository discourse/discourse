import { on, observes } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
import { iconHTML } from "discourse-common/lib/icon-library";

export default Ember.Component.extend({
  layoutName: "select-box-kit/templates/components/select-box-kit",
  classNames: "select-box-kit",
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
  isFocused: false,
  isHidden: false,
  renderBody: false,
  tabindex: 0,
  scrollableParentSelector: ".modal-body",
  headerCaretUpIcon: "caret-up",
  headerCaretDownIcon: "caret-down",
  headerIcon: null,
  value: null,
  none: null,
  highlightedValue: null,
  noContentLabel: "select_box.no_content",
  valueAttribute: "id",
  nameProperty: "name",
  filterable: false,
  filterFocused: false,
  filter: "",
  filterPlaceholder: I18n.t("select_box.filter_placeholder"),
  filterIcon: "search",
  rowComponent: "select-box-kit/select-box-kit-row",
  filterComponent: "select-box-kit/select-box-kit-filter",
  headerComponent: "select-box-kit/select-box-kit-header",
  collectionComponent: "select-box-kit/select-box-kit-collection",
  collectionHeight: 200,
  verticalOffset: 0,
  horizontalOffset: 0,
  fullWidthOnMobile: false,
  castInteger: false,

  init() {
    this._super();

    if ($(window).outerWidth(false) <= 420) {
      this.set("filterable", false);
    }

    this.set("componentId", this.elemendId);
  },

  @computed("content.[]")
  computedContent(content) {
    return this.formatContents(content || []);
  },

  @computed("value", "none", "computedContent.firstObject.value")
  computedValue(value, none, firstContentValue) {
    if (Ember.isNone(value) && Ember.isNone(none)) {
      return firstContentValue;
    }

    return value;
  },

  @computed("selectedContents.firstObject.name")
  headerText(name) {
    return Ember.isNone(name) ? "select_box.default_header_text" : name;
  },

  click(event) {
    event.stopPropagation();
  },

  filterFunction(content) {
    return (selectBox) => {
      const filter = selectBox.get("filter").toLowerCase();
      return _.filter(content, (c) => {
        return Ember.get(c, "name").toLowerCase().indexOf(filter) > -1;
      });
    };
  },

  @computed
  titleForRow() {
    return rowComponent => rowComponent.get("content.name");
  },

  @computed("highlightedValue")
  shouldHighlightRow(highlightedValue) {
    return rowComponent => highlightedValue === rowComponent.get("content.value");
  },

  @computed
  iconForRow() {
    return rowComponent => {
      const content = rowComponent.get("content");
      if (Ember.get(content, "originalContent.icon")) {
        const iconName = Ember.get(content, "originalContent.icon");
        const iconClass = Ember.get(content, "originalContent.iconClass");
        return iconHTML(iconName, { class: iconClass });
      }

      return null;
    };
  },

  @computed("computedValue")
  shouldSelectRow(computedValue) {
    return rowComponent => computedValue === rowComponent.get("content.value");
  },

  nameForContent(content) {
    if (Ember.isNone(content)) {
      return null;
    }

    if (typeof content === "object") {
      return Ember.get(content, this.get("nameProperty"));
    }

    return content;
  },

  valueForContent(content) {
    switch (typeof content) {
    case "string":
      return this._castInteger(content);
    default:
      return this._castInteger(Ember.get(content, this.get("valueAttribute")));
    }
  },

  @computed
  templateForRow() { return this._baseRowTemplate(); },

  @computed
  templateForNoneRow() { return this._baseRowTemplate(); },

  _baseRowTemplate() {
    return (rowComponent) => {
      let template = "";

      const icon = rowComponent.get("icon");
      if (icon) { template += icon; }

      const name = rowComponent.get("content.name");
      template += `<p class="text">${Handlebars.escapeExpression(name)}</p>`;

      return template;
    };
  },

  applyDirection() {
    let options = { left: "auto", bottom: "auto", top: "auto" };
    const headerHeight = this.$(".select-box-kit-header").outerHeight(false);
    const filterHeight = this.$(".select-box-kit-filter").outerHeight(false);
    const bodyHeight = this.$(".select-box-kit-body").outerHeight(false);
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
      const bodyWidth = this.$(".select-box-kit-body").outerWidth(false);
      const hasRightSpace = (windowWidth - (this.get("horizontalOffset") + offsetLeft + filterHeight + bodyWidth) > 0);

      if (hasRightSpace) {
        this.setProperties({ isLeftAligned: true, isRightAligned: false });
        options.left = this.get("horizontalOffset");
      } else {
        this.setProperties({ isLeftAligned: false, isRightAligned: true });
        options.right = this.get("horizontalOffset");
      }
    }

    const componentHeight = this.get("verticalOffset") + bodyHeight + headerHeight;
    const hasBelowSpace = windowHeight - offsetTop - componentHeight > 0;
    if (hasBelowSpace) {
      this.setProperties({ isBelow: true, isAbove: false });
      options.top = headerHeight + this.get("verticalOffset");
    } else {
      this.setProperties({ isBelow: false, isAbove: true });
      options.bottom = headerHeight + this.get("verticalOffset");
    }

    this.$(".select-box-kit-body").css(options);
  },

  @computed("none")
  computedNone(none) {
    if (Ember.isNone(none)) {
      return null;
    }

    switch (typeof none) {
    case "string":
      return Ember.Object.create({ name: I18n.t(none), value: "none" });
    default:
      return this.formatContent(none);
    }
  },

  @computed("computedValue", "computedContent.[]")
  selectedContents(computedValue, computedContent) {
    if (Ember.isNone(computedValue)) {
      return [];
    }

    return [ computedContent.findBy("value", computedValue) ];
  },

  formatContent(content) {
    return {
      value: this.valueForContent(content),
      name: this.nameForContent(content),
      originalContent: content
    };
  },

  formatContents(contents) {
    return contents.map(content => this.formatContent(content));
  },

  @on("willDestroyElement")
  _removeDocumentListeners: function() {
    $(document).off("click.select-box-kit");
    $(window).off("resize.select-box-kit");
  },

  @on("willDestroyElement")
  _unbindEvents() {
    this.$(".select-box-kit-offscreen").off(
      "focusin.select-box-kit",
      "focusout.select-box-kit",
      "keydown.select-box-kit"
    );
    this.$(".filter-query").off("focusin.select-box-kit", "focusout.select-box-kit");
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

      this.$(".select-box-kit-collection").css("max-height", this.get("collectionHeight"));

      Ember.run.schedule("afterRender", () => {
        this.applyDirection();
        this._positionSelectBoxWrapper();
      });
    }
  },

  keyDown(event) {
    const keyCode = event.keyCode || event.which;

    if (this.get("isExpanded")) {
      if ((keyCode === 13 || keyCode === 9) && Ember.isPresent(this.get("highlightedValue"))) {
        event.preventDefault();
        this.send("onSelect", this.get("highlightedContent.value"));
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
      .off("click.select-box-kit")
      .on("click.select-box-kit", (event) => {
        if (this.isDestroying || this.isDestroyed) { return; }

        if (!$(event.target).closest(this.$()).length) {
          this.set("isExpanded", false);
        }
      });

    $(window).on("resize.select-box-kit", () => this.set("isExpanded", false) );
  },

  @on("didInsertElement")
  _bindEvents() {
    this.$(".select-box-kit-offscreen")
      .on("focusin.select-box-kit", () => this.set("isFocused", true) )
      .on("focusout.select-box-kit", () => this.set("isFocused", false) );

    this.$(".filter-query")
      .on("focusin.select-box-kit", () => this.set("filterFocused", true) )
      .on("focusout.select-box-kit", () => this.set("filterFocused", false) );

    this.$(".select-box-kit-offscreen").on("keydown.select-box-kit", (event) => {
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
    if (this.get("isExpanded") === true) {
      this.setProperties({ highlightedValue: null, renderBody: true, focused: false });

      if (this.get("filterable") === true) {
        Ember.run.schedule("afterRender", () => this.$(".filter-query").focus());
      }
    };
  },

  @computed("highlightedValue", "computedContent.[]")
  highlightedContent(highlightedValue, computedContent) {
    if (Ember.isNone(highlightedValue)) {
      return null;
    }

    return computedContent.find(c => Ember.get(c, "value") === highlightedValue );
  },

  @computed("filter", "computedContent.[]")
  filteredContent(filter, computedContent) {
    let filteredContent = computedContent;

    if (!Ember.isEmpty(filter)) {
      filteredContent = this.filterFunction(filteredContent)(this);

      if (!Ember.isEmpty(filteredContent)) {
        this.set("highlightedValue", filteredContent.get("firstObject.value"));
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

    onHoverRow(value) {
      this.set("highlightedValue", value);
    },

    onClearSelection() {
      this.defaultOnSelect();
      this.set("value", null);
    },

    onSelect(value) {
      this.defaultOnSelect();
      this.set("value", value);
    },

    onDeselect() {
      this.set("value", null);
    }
  },

  _positionSelectBoxWrapper() {
    const headerHeight = this.$(".select-box-kit-header").outerHeight(false);

    this.$(".select-box-kit-wrapper").css({
      width: this.$().width(),
      height: headerHeight + this.$(".select-box-kit-body").outerHeight(false)
    });
  },

  _castInteger(value) {
    if (this.get("castInteger") === true && Ember.isPresent(value)) {
      return parseInt(value, 10);
    }

    return value;
  },

  _applyFixedPosition(width, height) {
    const $placeholder = $(`<div class='select-box-kit-fixed-placeholder-${this.get("componentId")}' style='vertical-align: middle; height: ${height}px; width: ${width}px; line-height: ${height}px;display:inline-block'></div>`);

    this.$()
      .before($placeholder)
      .css({
        width,
        position: "fixed",
        "margin-top": -this.get("scrollableParent").scrollTop(),
        "margin-left": -width
      });

    this.get("scrollableParent").on("scroll.select-box-kit", () => this.set("isExpanded", false) );
  },

  _removeFixedPosition() {
    $(`.select-box-kit-fixed-placeholder-${this.get("componentId")}`).remove();
    this.$().css({
      top: "auto",
      left: "auto",
      "margin-left": "auto",
      "margin-top": "auto",
      position: "relative"
    });

    this.get("scrollableParent").off("scroll.select-box-kit");
  },

  _handleDownArrow() {
    this._handleArrow("down");
  },

  _handleUpArrow() {
    this._handleArrow("up");
  },

  _handleArrow(direction) {
    const content = this.get("filteredContent");
    const highlightedContent = content.findBy("value", this.get("highlightedValue"));
    const currentIndex = content.indexOf(highlightedContent);

    if (direction === "down") {
      if (currentIndex < 0) {
        this.set("highlightedValue", Ember.get(content, "firstObject.value"));
      } else if(currentIndex + 1 < content.length) {
        this.set("highlightedValue", Ember.get(content, `${currentIndex+1}.value`));
      }
    } else {
      if (currentIndex <= 0) {
        this.set("highlightedValue", Ember.get(content, "firstObject.value"));
      } else if(currentIndex - 1 < content.length) {
        this.set("highlightedValue", Ember.get(content, `${currentIndex-1}.value`));
      }
    }

    Ember.run.schedule("afterRender", () => {
      const $highlightedRow = this.$(".select-box-kit-row.is-highlighted");

      if ($highlightedRow.length === 0) { return; }

      const $collection = this.$(".select-box-kit-collection");
      const rowOffset = $highlightedRow.offset();
      const bodyOffset = $collection.offset();
      $collection.scrollTop(rowOffset.top - bodyOffset.top);
    });
  },

  defaultOnSelect() {
    this.setProperties({ isExpanded: false, filter: "" });
  }
});
