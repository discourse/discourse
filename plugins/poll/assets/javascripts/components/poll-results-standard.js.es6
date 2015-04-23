export default Em.Component.extend({
  tagName: "table",
  classNames: ["results"],

  options: function() {
    const totalVotes = this.get("poll.total_votes"),
          backgroundColor = this.get("poll.background");

    this.get("poll.options").forEach(option => {
      const percentage = Math.floor(100 * option.get("votes") / totalVotes),
            styles = ["width: " + percentage + "%"];

      if (backgroundColor) { styles.push("background: " + backgroundColor); }

      option.setProperties({
        percentage: percentage,
        title: I18n.t("poll.option_title", { count: option.get("votes") }),
        style: styles.join(";")
      });
    });

    return this.get("poll.options");
  }.property("poll.total_votes", "poll.options.[]")

});
