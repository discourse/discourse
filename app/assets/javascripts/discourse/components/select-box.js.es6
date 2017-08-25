import { on, observes } from "ember-addons/ember-computed-decorators";
import { iconHTML } from "discourse-common/lib/icon-library";

export default Ember.Component.extend({
  layoutName: "components/select-box",

  classNames: "select-box",
  classNameBindings: ["expanded:is-expanded"],

  expanded: false,
  focused: false,
  filterFocused: false,
  renderBody: false,
  wrapper: true,
  tabindex: 0,

  caretUpIcon: "caret-up",
  caretDownIcon: "caret-down",
  headerText: null,
  dynamicHeaderText: true,
  icon: null,

  value: null,
  selectedContent: null,
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

  width: 220,
  maxCollectionHeight: 200,
  verticalOffset: 0,
  horizontalOffset: 0,

  castInteger: false,

  filterFunction: function() {
    return (selectBox) => {
      const filter = selectBox.get("filter").toLowerCase();
      return _.filter(selectBox.get("content"), (content) => {
        return content[selectBox.get("textKey")].toLowerCase().indexOf(filter) > -1;
      });
    };
  },

  selectBoxRowTemplate: function() {
    return (rowComponent) => {
      let template = "";

      if (rowComponent.get("content.icon")) {
        template += iconHTML(Handlebars.escapeExpression(rowComponent.get("content.icon")));
      }

      template += `<p class="text">${Handlebars.escapeExpression(rowComponent.get("text"))}</p>`;

      return template;
    };
  }.property(),

  applyDirection() {
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

  init() {
    this._super();

    if (!this.get("content")) {
      this.set("content", []);
    }

    if (this.site.isMobileDevice) {
      this.set("filterable", false);
    }

    this.set("headerText", Handlebars.escapeExpression(this.get("headerText")));

    this.setProperties({
      componentId: this.elementId,
      filteredContent: []
    });
  },

  @on("willDestroyElement")
  _unbindEvents: function() {
    $(window).off("resize.select-box");
    $(document).off("click.select-box", "keydown.select-box");
    this.$(".select-box-offscreen").off(
      "focusin.select-box",
      "focusout.select-box",
      "keydown.select-box"
    );
    this.$(".filter-query").off("focusin.select-box", "focusout.select-box");
  },

  @on("didRender")
  _configureSelectBoxDOM: function() {
    this.$().css("width", this.get("width"));
    this.$(".select-box-header").css("height", this.$().css("height"));
    this.$(".select-box-filter").css("height", this.$().css("height"));

    if (this.get("expanded")) {
      this.$(".select-box-body").css("width", this.$().css("width"));
      this.$(".select-box-collection").css("max-height", this.get("maxCollectionHeight"));

      this._bindTab();

      Ember.run.schedule("afterRender", () => {
        this.applyDirection();

        if (this.get("wrapper")) {
          this._positionSelectBoxWrapper();
        }
      });
    } else {
      $(document).off("keydown.select-box");

      if (this.get("wrapper")) {
        this.$(".select-box-wrapper").hide();
      }
    }
  },

  @on("didInsertElement")
  _bindEvents: function() {
    $(document).on("click.select-box", (event) => {
      const clickOutside = $(event.target).parents(".select-box").attr("id") !== this.$().attr("id");
      if (this.get("expanded") && clickOutside) {
        this.setProperties({ expanded: false, focused: false });
      }
    });

    this.$(".select-box-offscreen").on("focusin.select-box", () => {
      this.set("focused", true);
    });
    this.$(".select-box-offscreen").on("focusout.select-box", () => {
      this.set("focused", false);
    });

    this.$(".filter-query").on("focusin.select-box", () => {
      this.set("filterFocused", true);
    });
    this.$(".filter-query").on("focusout.select-box", () => {
      this.set("filterFocused", false);
    });

    this.$(".select-box-offscreen").on("keydown.select-box", (event) => {
      const keyCode = event.keyCode || event.which;

      if (keyCode === 13 || keyCode === 40) {
        this.setProperties({expanded: true, focused: false});
        return false;
      }

      if (keyCode === 27) {
        this.$(".select-box-offscreen").blur();
        return false;
      }

      if (keyCode >= 65 && keyCode <= 90) {
        this.setProperties({expanded: true, focused: false});
        Ember.run.schedule("afterRender", () => {
          this.$(".filter-query").focus().val(String.fromCharCode(keyCode));
        });
      }
    });

    $(window).on("resize.select-box", () => this.set("expanded", false) );
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
      const filtered = this.filterFunction()(this);
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

      if (this.get("filterable")) {
        Ember.run.schedule("afterRender", () => this.$(".filter-query").focus());
      }
    };
  },

  @observes("content.[]", "value")
  @on("didReceiveAttrs")
  _contentChanged: function() {
    if (!Ember.isNone(this.get("value"))) {
      this.set("lastHoveredId", this.get("content")[this.get("idKey")]);
    } else {
      this.set("lastHoveredId", null);
    }

    this.set("filteredContent", this._remapContent(this.get("content")));
    this._setSelectedContent(this.get("content"));

    if (this.get("dynamicHeaderText")) {
      if (!Ember.isNone(this.get("selectedContent.text"))) {
        this.set("headerText", this.get("selectedContent.text"));
      }
    }
  },

  actions: {
    onToggle() {
      this.toggleProperty("expanded");
    },

    onFilterChange(filter) {
      this.set("filter", filter);
    },

    onSelectRow(id) {
      if (this.get("castInteger")) {
        id = parseInt(id, 10);
      }

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
    let id = content[this.get("idKey")];
    if (this.get("castInteger")) {
      id = parseInt(id, 10);
    }

    return {
      id,
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
      width: this.$().width(),
      display: "block",
      height: headerHeight + this.$(".select-box-body").outerHeight()
    });
  },
});
