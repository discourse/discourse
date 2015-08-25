import ScrollTop from 'discourse/mixins/scroll-top';
import LoadMore from "discourse/mixins/load-more";

export default Ember.View.extend(ScrollTop, LoadMore, {
  eyelineSelector: '.group-members tr',
});
