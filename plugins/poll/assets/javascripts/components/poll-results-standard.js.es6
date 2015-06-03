export default Em.Component.extend({
  tagName: "ul",
  classNames: ["results"],

  options: function() {
    const voters = this.get("poll.voters");

    this.get("poll.options").forEach(option => {
      const percentage = voters === 0 ? 0 : Math.floor(100 * option.get("votes") / voters),
            style = "width: " + percentage + "%".htmlSafe();

      option.setProperties({
        percentage,
        style,
        title: I18n.t("poll.option_title", { count: option.get("votes") })
      });
    });

    return this.get("poll.options");
  }.property("poll.voters", "poll.options.[]")

});
