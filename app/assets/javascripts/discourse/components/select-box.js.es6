import { on, observes } from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  classNames: "select-box",

  classNameBindings: ["expanded:is-expanded"],

  attributeBindings: ['componentStyle:style'],
  componentStyle: function() {
    return Ember.String.htmlSafe(`width: ${this.get("maxWidth")}px`);
  }.property("maxWidth"),

  expanded: false,
  focused: false,

  caretUpIcon: "caret-up",
  caretDownIcon: "caret-down",
  headerText: null,
  icon: null,

  value: null,
  noContentText: I18n.t("select_box.no_content"),
  lastHoveredId: null,

  idKey: "id",
  textKey: "text",
  iconKey: "icon",

  filterable: false,
  filter: "",
  filterPlaceholder: I18n.t("select_box.filter_placeholder"),
  filterIcon: "search",

  selectBoxRowComponent: "select-box/select-box-row",
  selectBoxFilterComponent: "select-box/select-box-filter",
  selectBoxHeaderComponent: "select-box/select-box-header",
  selectBoxCollectionComponent: "select-box/select-box-collection",

  maxCollectionHeight: 200,
  maxWidth: 200,
  verticalOffset: 0,
  horizontalOffset: 0,

  renderBody: false,

  init() {
    this._super();

    if (!this.get("content")) {
      this.set("content", []);
    }

    this.setProperties({
      componentId: this.elementId,
      filteredContent: [],
      selectedContent: {}
    });
  },

  @observes("value")
  _valueChanged: function() {
    if (Ember.isNone(this.get("value"))) {
      this.set("lastHoveredId", null);
    }

    this.set("filteredContent", this._remapContent(this.get("content")));
  },

  @observes("filter")
  _filterChanged: function() {
    if (Ember.isEmpty(this.get("filter"))) {
      this.set("filteredContent", this._remapContent(this.get("content")));
    } else {
      const filtered = _.filter(this.get("content"), (content) => {
        return content[this.get("textKey")].toLowerCase().indexOf(this.get("filter")) > -1;
      });
      this.set("filteredContent", this._remapContent(filtered));
    }
  },

  @observes("expanded")
  _expandedChanged: function() {
    if (this.get("expanded")) {
      this.setProperties({ focused: false, renderBody: true });

      if (Ember.isNone(this.get("lastHoveredId"))) {
        this.set("lastHoveredId", this.get("value"));
      }
    };
  },

  @on("willDestroyElement")
  _unbindEvents: function() {
    $(document).off("click.select-box");
    $(document).off("keydown.select-box");
    this.$(".select-box-offscreen").off("focusin.select-box");
    this.$(".select-box-offscreen").off("focusout.select-box");
  },

  @on("didRender")
  _configureSelectBoxDOM: function() {
    if (this.get("expanded")) {
      this.$(".select-box-body").css('width', this.get("maxWidth"));
      this.$(".select-box-filter .filter-query").focus();
      this.$(".select-box-collection").css("max-height", this.get("maxCollectionHeight"));

      this._bindTab();
      this._applyDirection();
      this._positionSelectBoxWrapper();
    } else {
      $(document).off("keydown.select-box");
      this.$(".select-box-wrapper").hide();
    }
  },

  @observes("content.[]")
  @on("didReceiveAttrs")
  _contentChanged: function() {
    if (!Ember.isNone(this.get("value"))) {
      this.set("lastHoveredId", this.get("content")[this.get("idKey")]);
    } else {
      this.set("lastHoveredId", null);
    }

    this.set("filteredContent", this._remapContent(this.get("content")));
    this._setSelectedContent(this.get("content"));
    this.set("headerText", this.get("defaultHeaderText") || this.get("selectedContent.text"));
  },

  @on("didInsertElement")
  _bindEvents: function() {
    $(document).on("click.select-box", (event) => {
      const clickOutside = $(event.target).parents(".select-box").attr("id") !== this.$().attr("id");
      if (this.get("expanded") && clickOutside) {
        this.setProperties({
          expanded: false,
          focused: false
        });
      }
    });

    this.$(".select-box-offscreen").on("focusin.select-box", () => {
      this.set("focused", true);
    });

    this.$(".select-box-offscreen").on("focusout.select-box", () => {
      this.set("focused", false);
    });
  },

  actions: {
    onToggle() {
      this.toggleProperty("expanded");
    },

    onFilterChange(filter) {
      this.set("filter", filter);
    },

    onSelectRow(id) {
      this.setProperties({
        value: id,
        expanded: false
      });
    },

    onHoverRow(id) {
      this.set("lastHoveredId", id);
    }
  },

  _setSelectedContent(content) {
    const selectedContent = content.find((c) => {
      return c[this.get("idKey")] === this.get("value");
    });

    if (!Ember.isNone(selectedContent)) {
      this.set("selectedContent", this._normalizeContent(selectedContent));
    }
  },

  _remapContent(content) {
    return content.map(c => this._normalizeContent(c));
  },

  _normalizeContent(content) {
    return {
      id: content[this.get("idKey")],
      text: content[this.get("textKey")],
      icon: content[this.get("iconKey")]
    };
  },

  _bindTab() {
    $(document).on("keydown.select-box", (event) => {
      const keyCode = event.keyCode || event.which;
      if (keyCode === 9) {
        this.set("expanded", false);
      }
    });
  },

  _positionSelectBoxWrapper() {
    const headerHeight = this.$(".select-box-header").outerHeight();

    this.$(".select-box-wrapper").css({
      width: this.get("maxWidth"),
      display: "block",
      height: headerHeight + this.$(".select-box-body").outerHeight()
    });
  },

  _applyDirection() {
    this.$().removeClass("is-reversed");

    const offsetTop = this.$()[0].getBoundingClientRect().top;
    const windowHeight = $(window).height();
    const headerHeight = this.$(".select-box-header").outerHeight();
    const filterHeight = this.$(".select-box-filter").outerHeight();

    if (windowHeight - (offsetTop + this.get("maxCollectionHeight") + filterHeight + headerHeight) < 0) {
      this.$().addClass("is-reversed");
      this.$(".select-box-body").css({
        left: this.get("horizontalOffset"),
        top: "",
        bottom: headerHeight + this.get("verticalOffset")
      });
    } else {
      this.$(".select-box-body").css({
        left: this.get("horizontalOffset"),
        top: headerHeight + this.get("verticalOffset"),
        bottom: ""
      });
    }
  },
});
