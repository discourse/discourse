import DiscourseURL from "discourse/lib/url";
import CleansUp from "discourse/mixins/cleans-up";
import computed from "ember-addons/ember-computed-decorators";

function entranceDate(dt, showTime) {
  const today = new Date();

  if (dt.toDateString() === today.toDateString()) {
    return moment(dt).format(I18n.t("dates.time"));
  }

  if (dt.getYear() === today.getYear()) {
    // No year
    return moment(dt).format(
      showTime
        ? I18n.t("dates.long_date_without_year_with_linebreak")
        : I18n.t("dates.long_no_year_no_time")
    );
  }

  return moment(dt).format(
    showTime
      ? I18n.t("dates.long_date_with_year_with_linebreak")
      : I18n.t("dates.long_date_with_year_without_time")
  );
}

export default Ember.Component.extend(CleansUp, {
  elementId: "topic-entrance",
  classNameBindings: ["visible::hidden"],
  _position: null,
  topic: null,
  visible: null,

  @computed("topic.created_at") createdDate: createdAt => new Date(createdAt),

  @computed("topic.bumped_at") bumpedDate: bumpedAt => new Date(bumpedAt),

  @computed("createdDate", "bumpedDate")
  showTime(createdDate, bumpedDate) {
    return (
      bumpedDate.getTime() - createdDate.getTime() < 1000 * 60 * 60 * 24 * 2
    );
  },

  @computed("createdDate", "showTime")
  topDate: (createdDate, showTime) => entranceDate(createdDate, showTime),

  @computed("bumpedDate", "showTime")
  bottomDate: (bumpedDate, showTime) => entranceDate(bumpedDate, showTime),

  didInsertElement() {
    this._super();
    this.appEvents.on("topic-entrance:show", data => this._show(data));
  },

  _setCSS() {
    const pos = this._position;
    const $self = this.$();
    const width = $self.width();
    const height = $self.height();
    pos.left = parseInt(pos.left) - width / 2;
    pos.top = parseInt(pos.top) - height / 2;

    const windowWidth = $(window).width();
    if (pos.left + width > windowWidth) {
      pos.left = windowWidth - width - 15;
    }
    $self.css(pos);
  },

  _show(data) {
    this._position = data.position;

    this.set("topic", data.topic);
    this.set("visible", true);

    Ember.run.scheduleOnce("afterRender", this, this._setCSS);

    $("html")
      .off("mousedown.topic-entrance")
      .on("mousedown.topic-entrance", e => {
        const $target = $(e.target);
        if (
          $target.prop("id") === "topic-entrance" ||
          this.$().has($target).length !== 0
        ) {
          return;
        }
        this.cleanUp();
      });
  },

  cleanUp() {
    this.set("topic", null);
    this.set("visible", false);
    $("html").off("mousedown.topic-entrance");
  },

  willDestroyElement() {
    this.appEvents.off("topic-entrance:show");
  },

  _jumpTo(destination) {
    this.cleanUp();
    DiscourseURL.routeTo(destination);
  },

  actions: {
    enterTop() {
      this._jumpTo(this.get("topic.url"));
    },

    enterBottom() {
      this._jumpTo(this.get("topic.lastPostUrl"));
    }
  }
});
