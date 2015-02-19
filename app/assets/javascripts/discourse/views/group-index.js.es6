import LoadMore from "discourse/mixins/load-more";

export default Discourse.View.extend(Discourse.ScrollTop, LoadMore, {
  eyelineSelector: '.user-stream .item',
});
