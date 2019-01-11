import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";

const MAX_COMPONENTS = 4;

export default Ember.Component.extend({
  childrenExpanded: false,
  classNames: ["themes-list-item"],
  classNameBindings: ["theme.selected:selected"],
  hasComponents: Ember.computed.gt("children.length", 0),
  displayComponents: Ember.computed.and("hasComponents", "theme.isActive"),
  displayHasMore: Ember.computed.gt("theme.childThemes.length", MAX_COMPONENTS),

  click(e) {
    if (!$(e.target).hasClass("others-count")) {
      this.navigateToTheme();
    }
  },

  init() {
    this._super(...arguments);
    this.scheduleAnimation();
  },

  @observes("theme.selected")
  triggerAnimation() {
    this.animate();
  },

  scheduleAnimation() {
    Ember.run.schedule("afterRender", () => {
      this.animate(true);
    });
  },

  animate(isInitial) {
    const $container = this.$();
    const $list = this.$(".components-list");
    if ($list.length === 0 || Ember.testing) {
      return;
    }
    const duration = 300;
    if (this.get("theme.selected")) {
      this.collapseComponentsList($container, $list, duration);
    } else if (!isInitial) {
      this.expandComponentsList($container, $list, duration);
    }
  },

  @computed(
    "theme.component",
    "theme.childThemes.@each.name",
    "theme.childThemes.length",
    "childrenExpanded"
  )
  children() {
    const theme = this.get("theme");
    let children = theme.get("childThemes");
    if (theme.get("component") || !children) {
      return [];
    }
    children = this.get("childrenExpanded")
      ? children
      : children.slice(0, MAX_COMPONENTS);
    return children.map(t => t.get("name"));
  },

  @computed("children")
  childrenString(children) {
    return children.join(", ");
  },

  @computed(
    "theme.childThemes.length",
    "theme.component",
    "childrenExpanded",
    "children.length"
  )
  moreCount(childrenCount, component, expanded) {
    if (component || !childrenCount || expanded) {
      return 0;
    }
    return childrenCount - MAX_COMPONENTS;
  },

  expandComponentsList($container, $list, duration) {
    $container.css("height", `${$container.height()}px`);
    $list.css("display", "");
    $container.animate(
      {
        height: `${$container.height() + $list.outerHeight(true)}px`
      },
      {
        duration,
        done: () => {
          $list.css("display", "");
          $container.css("height", "");
        }
      }
    );
    $list.animate(
      {
        opacity: 1
      },
      {
        duration
      }
    );
  },

  collapseComponentsList($container, $list, duration) {
    $container.animate(
      {
        height: `${$container.height() - $list.outerHeight(true)}px`
      },
      {
        duration,
        done: () => {
          $list.css("display", "none");
          $container.css("height", "");
        }
      }
    );
    $list.animate(
      {
        opacity: 0
      },
      {
        duration
      }
    );
  },

  actions: {
    toggleChildrenExpanded() {
      this.toggleProperty("childrenExpanded");
    }
  }
});
