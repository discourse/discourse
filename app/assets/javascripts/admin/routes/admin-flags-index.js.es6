export default Discourse.Route.extend({
  redirect() {
    let segment = this.siteSettings.flags_default_topics
      ? "topics"
      : "postsActive";
    this.replaceWith(`adminFlags.${segment}`);
  }
});
