export default Discourse.Route.extend({
  redirect() {
    this.replaceWith('adminFlags.list', 'active');
  }
});
