import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  showSelector: true,
  shouldHide: false,
  defaultUsernameCount: 0,

  didInsertElement() {
    this._super(...arguments);

    if (this.get("focusTarget") === "usernames") {
      this.$("input").putCursorAtEnd();
    }
  },

  @observes("usernames")
  _checkWidth() {
    let width = 0;
    const $acWrap = this.$().find(".ac-wrap");
    const limit = $acWrap.width();
    this.set("defaultUsernameCount", 0);

    $acWrap
      .find(".item")
      .toArray()
      .forEach(item => {
        width += $(item).outerWidth(true);
        const result = width < limit;

        if (result) this.incrementProperty("defaultUsernameCount");
        return result;
      });

    if (width >= limit) {
      this.set("shouldHide", true);
    } else {
      this.set("shouldHide", false);
    }
  },

  @observes("shouldHide")
  _setFocus() {
    const selector =
      "#reply-control #reply-title, #reply-control .d-editor-input";

    if (this.get("shouldHide")) {
      $(selector).on("focus.composer-user-selector", () => {
        this.set("showSelector", false);
        this.appEvents.trigger("composer:resize");
      });
    } else {
      $(selector).off("focus.composer-user-selector");
    }
  },

  @computed("usernames")
  splitUsernames(usernames) {
    return usernames.split(",");
  },

  @computed("splitUsernames", "defaultUsernameCount")
  limitedUsernames(splitUsernames, count) {
    return splitUsernames.slice(0, count).join(", ");
  },

  @computed("splitUsernames", "defaultUsernameCount")
  hiddenUsersCount(splitUsernames, count) {
    return `${splitUsernames.length - count} ${I18n.t("more")}`;
  },

  actions: {
    toggleSelector() {
      this.set("showSelector", true);

      Ember.run.schedule("afterRender", () => {
        this.$()
          .find("input")
          .focus();
      });
    },

    triggerResize() {
      this.appEvents.trigger("composer:resize");
      const $this = this.$().find(".ac-wrap");
      if ($this.height() >= 150) $this.scrollTop($this.height());
    }
  }
});
