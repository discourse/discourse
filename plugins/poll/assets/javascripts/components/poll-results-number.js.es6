import round from "discourse/plugins/poll/lib/round";

export default Em.Component.extend({
  tagName: "span",

  totalScore: function() {
    return _.reduce(this.get("poll.options"), function(total, o) {
      const value = parseInt(o.get("html"), 10),
            votes = parseInt(o.get("votes"), 10);
      return total + value * votes;
    }, 0);
  }.property("poll.options.@each.{html,votes}"),

  average: function() {
    return round(this.get("totalScore") / this.get("poll.total_votes"), -2);
  }.property("totalScore", "poll.total_votes"),

  averageRating: function() {
    return I18n.t("poll.average_rating", { average: this.get("average") });
  }.property("average"),

});
