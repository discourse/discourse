import { createWidget } from "discourse/widgets/widget";
import { i18n } from "discourse-i18n";

export default createWidget("post-gap", {
  tagName: "div.gap",
  buildKey: (attrs) => `post-gap-${attrs.pos}-${attrs.postId}`,

  defaultState() {
    return { loading: false };
  },

  html(attrs, state) {
    return state.loading
      ? i18n("loading")
      : i18n("post.gap", { count: attrs.gap.length });
  },

  click() {
    const { attrs, state } = this;

    if (state.loading) {
      return;
    }
    state.loading = true;

    const args = { gap: attrs.gap, post: this.model };
    return this.sendWidgetAction(
      attrs.pos === "before" ? "fillGapBefore" : "fillGapAfter",
      args
    ).then(() => {
      state.loading = false;
      this.appEvents.trigger("post-stream:gap-expanded", {
        post_id: this.model.id,
      });
    });
  },
});
