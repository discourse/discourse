export default Ember.Component.extend({
  allTime: true,
  tagName: "tr",
  reverseColors: Ember.computed.match(
    "report.type",
    /^(time_to_first_response|topics_with_no_response)$/
  ),
  classNameBindings: ["reverseColors"]
});
