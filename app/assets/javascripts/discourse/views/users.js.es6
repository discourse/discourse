import LoadMore from 'discourse/mixins/load-more';

export default Discourse.View.extend(LoadMore, {
  eyelineSelector: '.directory tbody tr'
});
