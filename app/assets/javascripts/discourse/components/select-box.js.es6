import { observes } from "ember-addons/ember-computed-decorators";

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
  icon: null,

  value: null,
  noDataText: I18n.t("select_box.no_data"),
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

  _renderBody: false,

  init() {
    this._super();

    if(!this.get("data")) {
      this.set("data", []);
    }

    this.setProperties({
      componentId: this.elementId,
      filteredData: [],
      selectedData: {}
    });
  },

  @observes("filter")
  _filter: function() {
    if(_.isEmpty(this.get("filter"))) {
      this.set("filteredData", this._remapData(this.get("data")));
    } else {
      const filtered = _.filter(this.get("data"), (data)=> {
        return data[this.get("textKey")].toLowerCase().indexOf(this.get("filter")) > -1;
      });
      this.set("filteredData", this._remapData(filtered));
    }
  },

  @observes("expanded", "filteredData")
  _expand: function() {
    if(this.get("expanded")) {
      this.setProperties({focused: false, _renderBody: true});

      Ember.$(document).on("keydown.select-box", (event) => {
        const keyCode = event.keyCode || event.which;
        if (keyCode === 9) {
          this.set("expanded", false);
        }
      });

      if(_.isUndefined(this.get("lastHoveredId"))) {
        this.set("lastHoveredId", this.get("value"));
      }

      Ember.run.scheduleOnce("afterRender", this, () => {
        this.$(".select-box-filter .filter-query").focus();
        this.$(".select-box-collection").css("max-height", this.get("maxCollectionHeight"));
        this.$().removeClass("is-reversed");

        const offsetTop = this.$()[0].getBoundingClientRect().top;
        const windowHeight = Ember.$(window).height();
        const headerHeight = this.$(".select-box-header").outerHeight();
        const filterHeight = this.$(".select-box-filter").outerHeight();

        if(windowHeight - (offsetTop + this.get("maxCollectionHeight") + filterHeight + headerHeight) < 0) {
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

        this.$(".select-box-wrapper").css({
          width: this.get("maxWidth"),
          display: "block",
          height: headerHeight + this.$(".select-box-body").outerHeight()
        });
      });
    } else {
      Ember.$(document).off("keydown.select-box");
      this.$(".select-box-wrapper").hide();
    };
  },

  willDestroyElement() {
    this._super();

    Ember.$(document).off("click.select-box");
    Ember.$(document).off("keydown.select-box");
    this.$(".select-box-offscreen").off("focusin.select-box");
    this.$(".select-box-offscreen").off("focusout.select-box");
  },

  didReceiveAttrs() {
    this._super();

    this.set("lastHoveredId", this.get("data")[this.get("idKey")]);
    this.set("filteredData", this._remapData(this.get("data")));
    this._setSelectedData(this.get("data"));
  },

  didRender() {
    this._super();

    this.$(".select-box-body").css('width', this.get("maxWidth"));
    this._expand();
  },

  didInsertElement() {
    this._super();

    Ember.$(document).on("click.select-box", (event) => {
      if(this.get("expanded") && $(event.target).parents(".select-box").attr("id") !== this.$().attr("id")) {
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

  _setSelectedData(data) {
    const selectedData = _.find(data, (d)=> {
      return d[this.get("idKey")] === this.get("value");
    });

    if(!_.isUndefined(selectedData)) {
      this.set("selectedData", this._normalizeData(selectedData));
    }
  },

  _remapData(data) {
    return data.map(d => this._normalizeData(d));
  },

  _normalizeData(data) {
    return {
      id: data[this.get("idKey")],
      text: data[this.get("textKey")],
      icon: data[this.get("iconKey")]
    };
  },
});
