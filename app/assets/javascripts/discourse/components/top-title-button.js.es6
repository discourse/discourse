import TopTitle from 'discourse/components/top-title';

export default TopTitle.extend({
  tagName: 'button',
  classNameBindings: [':btn', ':btn-default', 'unless:hidden'],

  click: function() {
    var url = this.get('period.showMoreUrl');
    if (url) {
      Discourse.URL.routeTo(url);
    }
  }
});
