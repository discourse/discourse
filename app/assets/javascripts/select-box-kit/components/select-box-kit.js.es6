import { on, observes } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
import { iconHTML } from "discourse-common/lib/icon-library";

export default Ember.Component.extend({
  attributeBindings: ["computedId:id"],
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
  filterable: true,
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
  },

  @computed("id")
  computedId(id) {
    if (Ember.isNone(id)) {
      return false;
    }

    return `select-box-kit-id_${id}`;
  },

  filterFunction(content) {
    return selectBox => {
      const filter = selectBox.get("filter").toLowerCase();
      return _.filter(content, c => {
        return Ember.get(c, "name").toLowerCase().indexOf(filter) > -1;
      });
    };
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
    return Ember.isNone(name) ? I18n.t("select_box.default_header_text") : name;
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

  @computed
  templateForRow() { return this._baseRowTemplate(); },

  @computed
  templateForNoneRow() { return this._baseRowTemplate(); },

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

  @on("willDestroyElement")
  _removeDocumentListeners() {
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
  _configureSelectBoxDOM() {
    if (this.get("scrollableParent").length === 1) {
      this._removeFixedPosition();
    }

    if (this.get("isExpanded")) {
      if (this.get("scrollableParent").length === 1) {
        this._applyFixedPosition(
          this.$().outerWidth(false),
          this.$().outerHeight(false)
        );
      }

      this.$(".select-box-kit-collection")
          .css("max-height", this.get("collectionHeight"));

      Ember.run.schedule("afterRender", () => {
        this._applyDirection();
        this._positionSelectBoxWrapper();
      });
    }
  },

  @on("didRender")
  _setupDocumentListeners() {
    $(document)
      .off("click.select-box-kit")
      .on("click.select-box-kit", event => {
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

    this.$(".select-box-kit-offscreen").on("keydown.select-box-kit", event => {
      const keyCode = event.keyCode || event.which;

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
    const $placeholder = $(`<div class='select-box-kit-fixed-placeholder-${this.elementId}' style='vertical-align: middle; height: ${height}px; line-height: ${height}px;display:inline-block'></div>`);

    this.$()
      .before($placeholder)
      .css({
        width,
        direction: $("html").css('direction'),
        position: "fixed",
        "margin-top": -this.get("scrollableParent").scrollTop(),
        "margin-left": 0
      });

    this.get("scrollableParent").on("scroll.select-box-kit", () => this.set("isExpanded", false) );
  },

  defaultOnSelect() {
    this.setProperties({ isExpanded: false, filter: "" });
  },

  keyDown(event) {
    const keyCode = event.keyCode || event.which;

    if (this.get("isFocused") === true && this.get("isExpanded") === false) {
      if (keyCode === 38 || keyCode === 40) {
        this.set("isExpanded", true);
        return;
      }
    }

    if (this.get("isExpanded") === false) { return; }

    if (keyCode === 9) {
      this.set("isExpanded", false);
      this.$(".select-box-kit-offscreen").focus();
    }

    if (keyCode === 27) {
      event.stopPropagation();
      this.set("isExpanded", false);
      this.$(".select-box-kit-offscreen").focus();
    }

    if (keyCode === 38 || keyCode === 40) {
      event.preventDefault();
      this._handleArrowKey(keyCode);
    }

    const oneRowIsHighlighted = Ember.isPresent(this.get("highlightedValue"));
    if ((keyCode === 13 || keyCode === 9) && oneRowIsHighlighted) {
      event.preventDefault();
      this.send("onSelect", this.get("highlightedContent.value"));
      this.$(".select-box-kit-offscreen").focus();
    }
  },

  _handleArrowKey(keyCode) {
    switch (keyCode) {
      case 38:
        Ember.run.throttle(this, this._handleUpArrow, 32);
        break;
      default:
        Ember.run.throttle(this, this._handleDownArrow, 32);
    }
  },

  _handleDownArrow() {
    const $rows = this.$(".select-box-kit-row");
    const $highlightedRrow = this.$(".select-box-kit-row.is-highlighted");
    const currentIndex = $rows.index($highlightedRrow);

    let nextIndex;

    if (currentIndex < 0) {
      nextIndex = 0;
    } else if (currentIndex + 1 < $rows.length) {
      nextIndex = currentIndex + 1;
    }

    this._rowSelection(nextIndex);
  },

  _handleUpArrow() {
    const $rows = this.$(".select-box-kit-row");
    const $highlightedRrow = this.$(".select-box-kit-row.is-highlighted");
    const currentIndex = $rows.index($highlightedRrow);

    let nextIndex;

    if (currentIndex <= 0) {
      nextIndex = 0;
    } else if (currentIndex - 1 < $rows.length) {
      nextIndex = currentIndex - 1;
    }

    this._rowSelection(nextIndex);
  },

  _rowSelection(nextIndex) {
    const $rows = this.$(".select-box-kit-row");
    const highlightableValue = $rows.eq(nextIndex).attr("data-value");
    const $highlightableRow = this.$(`.select-box-kit-row[data-value='${highlightableValue}']`);
    $highlightableRow.trigger("mouseover");

    Ember.run.schedule("afterRender", () => {
      if ($highlightableRow.length === 0) { return; }

      const $collection = this.$(".select-box-kit-collection");
      const currentOffset = $collection.offset().top +
                            $collection.outerHeight(false);
      const nextBottom = $highlightableRow.offset().top +
                         $highlightableRow.outerHeight(false);
      const nextOffset = $collection.scrollTop() + nextBottom - currentOffset;

      if (nextIndex === 0) {
        $collection.scrollTop(0);
      } else if (nextBottom > currentOffset) {
        $collection.scrollTop(nextOffset);
      }
    });
  },

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

  _applyDirection() {
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

  _removeFixedPosition() {
    $(`.select-box-kit-fixed-placeholder-${this.get("elementId")}`).remove();
    this.$().css({
      top: "auto",
      left: "auto",
      "margin-left": "auto",
      "margin-top": "auto",
      position: "relative"
    });

    this.get("scrollableParent").off("scroll.select-box-kit");
  },
});
