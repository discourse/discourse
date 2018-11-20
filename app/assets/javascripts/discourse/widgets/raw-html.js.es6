export default class RawHtml {
  constructor(attrs) {
    this.html = attrs.html;
  }

  init() {
    const $html = $(this.html);
    this.decorate($html);
    return $html[0];
  }

  decorate() {}

  update(prev) {
    if (prev.html === this.html) {
      return;
    }
    return this.init();
  }

  destroy() {}
}

RawHtml.prototype.type = "Widget";

// TODO: Improve how helpers are registered for vdom compliation
if (typeof Discourse !== "undefined") {
  Discourse.__widget_helpers.rawHtml = RawHtml;
}
