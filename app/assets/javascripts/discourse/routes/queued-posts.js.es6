import DiscourseRoute from 'discourse/routes/discourse';

export default DiscourseRoute.extend({
  model() {
    return this.store.find('queuedPost', {status: 'new'});
  }
});

