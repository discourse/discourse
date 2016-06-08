import round from "discourse/lib/round";
import computed from 'ember-addons/ember-computed-decorators';

export default Em.Component.extend({
  tagName: "span",

  @computed("poll.options.@each.{html,votes}")
  totalScore() {
    return _.reduce(this.get("poll.options"), function(total, o) {
      const value = parseInt(o.get("html"), 10),
            votes = parseInt(o.get("votes"), 10);
      return total + value * votes;
    }, 0);
  },

  @computed("totalScore", "poll.voters")
  average() {
    const voters = this.get("poll.voters");
    return voters === 0 ? 0 : round(this.get("totalScore") / voters, -2);
  },

  @computed("average")
  averageRating() {
    return I18n.t("poll.average_rating", { average: this.get("average") });
  },

});
