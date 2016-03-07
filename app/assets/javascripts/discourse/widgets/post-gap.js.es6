import { createWidget } from 'discourse/widgets/widget';

export default createWidget('post-gap', {
  tagName: 'div.gap.jagged-border',
  buildKey: (attrs) => `post-gap-${attrs.pos}-${attrs.postId}`,

  defaultState() {
    return { loading: false };
  },

  html(attrs, state) {
    return state.loading ? I18n.t('loading') : I18n.t('post.gap', {count: attrs.gap.length});
  },

  click() {
    const { attrs, state } = this;

    if (state.loading) { return; }
    state.loading = true;

    const args = { gap: attrs.gap, post: this.model };
    return this.sendWidgetAction(attrs.pos === 'before' ? 'fillGapBefore' : 'fillGapAfter', args);
  }
});
