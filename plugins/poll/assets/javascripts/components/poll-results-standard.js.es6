export default Em.Component.extend({
  tagName: "table",
  classNames: ["results"],

  options: function() {
    const voters = this.get("poll.voters"),
          backgroundColor = this.get("poll.background");

    this.get("poll.options").forEach(option => {
      const percentage = voters === 0 ? 0 : Math.floor(100 * option.get("votes") / voters),
            styles = ["width: " + percentage + "%"];

      if (backgroundColor) { styles.push("background: " + backgroundColor); }

      option.setProperties({
        percentage,
        title: I18n.t("poll.option_title", { count: option.get("votes") }),
        style: styles.join(";").htmlSafe()
      });
    });

    return this.get("poll.options");
  }.property("poll.voters", "poll.options.[]")

});
