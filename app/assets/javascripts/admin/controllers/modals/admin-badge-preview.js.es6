import { escapeExpression } from "discourse/lib/utilities";

export default Ember.Controller.extend({
  sample: Ember.computed.alias("model.sample"),
  errors: Ember.computed.alias("model.errors"),
  count: Ember.computed.alias("model.grant_count"),

  count_warning: function() {
    if (this.get("count") <= 10) {
      return this.get("sample.length") !== this.get("count");
    } else {
      return this.get("sample.length") !== 10;
    }
  }.property("count", "sample.length"),

  has_query_plan: function() {
    return !!this.get("model.query_plan");
  }.property("model.query_plan"),

  query_plan_html: function() {
    var raw = this.get("model.query_plan"),
      returned = "<pre class='badge-query-plan'>";

    raw.forEach(linehash => {
      returned += escapeExpression(linehash["QUERY PLAN"]);
      returned += "<br>";
    });

    returned += "</pre>";
    return returned;
  }.property("model.query_plan"),

  processed_sample: Ember.computed.map("model.sample", function(grant) {
    var i18nKey = "admin.badges.preview.grant.with",
      i18nParams = { username: escapeExpression(grant.username) };

    if (grant.post_id) {
      i18nKey += "_post";
      i18nParams.link =
        "<a href='/p/" +
        grant.post_id +
        "' data-auto-route='true'>" +
        Handlebars.Utils.escapeExpression(grant.title) +
        "</a>";
    }

    if (grant.granted_at) {
      i18nKey += "_time";
      i18nParams.time = escapeExpression(
        moment(grant.granted_at).format(I18n.t("dates.long_with_year"))
      );
    }

    return I18n.t(i18nKey, i18nParams);
  })
});
