import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  model(params) {
    // console.log('The model hook just ran!');
    // return 'Hello Ember!';
    return this.store.find('artist', params.id);
  },
});
