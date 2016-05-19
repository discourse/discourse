import evenRound from "discourse/plugins/poll/lib/even-round";
import computed from "ember-addons/ember-computed-decorators";

export default Em.Component.extend({
  tagName: "ul",
  classNames: ["results"],

  @computed("poll.voters", "poll.type", "poll.options.[]")
  options(voters, type) {
    const options = this.get("poll.options");

    let percentages = voters === 0 ?
      Array(options.length).fill(0) :
      _.map(options, o => 100 * o.get("votes") / voters);

    // properly round percentages
    if (type === "multiple") {
      // when the poll is multiple choices, just "round down"
      percentages = percentages.map(p => Math.floor(p));
    } else {
      // when the poll is single choice, adds up to 100%
      percentages = evenRound(percentages);
    }

    options.forEach((option, i) => {
      const percentage = percentages[i];
      const style = new Handlebars.SafeString(`width: ${percentage}%`);

      option.setProperties({
        percentage,
        style,
        title: I18n.t("poll.option_title", { count: option.get("votes") })
      });
    });

    return options;
  }

});
