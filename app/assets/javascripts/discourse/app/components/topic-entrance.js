import Component from "@ember/component";
import { action } from "@ember/object";
import { scheduleOnce } from "@ember/runloop";
import { service } from "@ember/service";
import { classNameBindings } from "@ember-decorators/component";
import { on } from "@ember-decorators/object";
import $ from "jquery";
import discourseComputed, { bind } from "discourse/lib/decorators";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";

function entranceDate(dt, showTime) {
  const today = new Date();

  if (dt.toDateString() === today.toDateString()) {
    return moment(dt).format(i18n("dates.time"));
  }

  if (dt.getYear() === today.getYear()) {
    // No year
    return moment(dt).format(
      showTime
        ? i18n("dates.long_date_without_year_with_linebreak")
        : i18n("dates.long_no_year_no_time")
    );
  }

  return moment(dt).format(
    showTime
      ? i18n("dates.long_date_with_year_with_linebreak")
      : i18n("dates.long_date_with_year_without_time")
  );
}

@classNameBindings("visible::hidden")
export default class TopicEntrance extends Component {
  @service router;
  @service session;
  @service historyStore;

  elementId = "topic-entrance";
  topic = null;
  visible = null;
  _position = null;
  _originalActiveElement = null;
  _activeButton = null;

  @discourseComputed("topic.created_at")
  createdDate(createdAt) {
    return new Date(createdAt);
  }

  @discourseComputed("topic.bumped_at")
  bumpedDate(bumpedAt) {
    return new Date(bumpedAt);
  }

  @discourseComputed("createdDate", "bumpedDate")
  showTime(createdDate, bumpedDate) {
    return (
      bumpedDate.getTime() - createdDate.getTime() < 1000 * 60 * 60 * 24 * 2
    );
  }

  @discourseComputed("createdDate", "showTime")
  topDate(createdDate, showTime) {
    return entranceDate(createdDate, showTime);
  }

  @discourseComputed("bumpedDate", "showTime")
  bottomDate(bumpedDate, showTime) {
    return entranceDate(bumpedDate, showTime);
  }

  @on("didInsertElement")
  _inserted() {
    this.appEvents.on("topic-entrance:show", this, "_show");
    this.appEvents.on("dom:clean", this, this.cleanUp);
  }

  @on("didDestroyElement")
  _destroyed() {
    this.appEvents.off("dom:clean", this, this.cleanUp);
  }

  _setCSS() {
    const pos = this._position;
    const $self = $(this.element);
    const width = $self.width();
    const height = $self.height();
    pos.left = parseInt(pos.left, 10) - width / 2;
    pos.top = parseInt(pos.top, 10) - height / 2;

    const windowWidth = $(window).width();
    if (pos.left + width > windowWidth) {
      pos.left = windowWidth - width - 15;
    }
    $self.css(pos);
  }

  @bind
  _escListener(e) {
    if (e.key === "Escape") {
      this.cleanUp();
    } else if (e.key === "Tab") {
      if (this._activeButton === "top") {
        this._jumpBottomButton().focus();
        this._activeButton = "bottom";
        e.preventDefault();
      } else if (this._activeButton === "bottom") {
        this._jumpTopButton().focus();
        this._activeButton = "top";
        e.preventDefault();
      }
    }
  }

  _jumpTopButton() {
    return this.element.querySelector(".jump-top");
  }

  _jumpBottomButton() {
    return this.element.querySelector(".jump-bottom");
  }

  _setupEscListener() {
    document.body.addEventListener("keydown", this._escListener);
  }

  _removeEscListener() {
    document.body.removeEventListener("keydown", this._escListener);
  }

  _trapFocus() {
    this._originalActiveElement = document.activeElement;
    this._jumpTopButton().focus();
    this._activeButton = "top";
  }

  _releaseFocus() {
    if (this._originalActiveElement) {
      this._originalActiveElement.focus();
      this._originalActiveElement = null;
    }
  }

  _applyDomChanges() {
    this._setCSS();
    this._setupEscListener();
    this._trapFocus();
  }

  _show(data) {
    this._position = data.position;

    this.setProperties({ topic: data.topic, visible: true });

    scheduleOnce("afterRender", this, this._applyDomChanges);

    $("html")
      .off("mousedown.topic-entrance")
      .on("mousedown.topic-entrance", (e) => {
        const $target = $(e.target);
        if (
          $target.prop("id") === "topic-entrance" ||
          $(this.element).has($target).length !== 0
        ) {
          return;
        }
        this.cleanUp();
      });
  }

  cleanUp() {
    this.setProperties({ topic: null, visible: false });
    $("html").off("mousedown.topic-entrance");
    this._removeEscListener();
    this._releaseFocus();
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    this.appEvents.off("topic-entrance:show", this, "_show");
  }

  _jumpTo(destination) {
    this.historyStore.set("lastTopicIdViewed", this.topic.id);

    this.cleanUp();
    DiscourseURL.routeTo(destination);
  }

  @action
  enterTop() {
    this._jumpTo(this.get("topic.url"));
  }

  @action
  enterBottom() {
    this._jumpTo(this.get("topic.lastPostUrl"));
  }
}
