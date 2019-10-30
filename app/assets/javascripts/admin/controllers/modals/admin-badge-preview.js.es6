import { alias, map } from "@ember/object/computed";
import Controller from "@ember/controller";
import { default as computed } from "ember-addons/ember-computed-decorators";
import { escapeExpression } from "discourse/lib/utilities";

export default Controller.extend({
  sample: alias("model.sample"),
  errors: alias("model.errors"),
  count: alias("model.grant_count"),

  @computed("count", "sample.length")
  countWarning(count, sampleLength) {
    if (count <= 10) {
      return sampleLength !== count;
    } else {
      return sampleLength !== 10;
    }
  },

  @computed("model.query_plan")
  hasQueryPlan(queryPlan) {
    return !!queryPlan;
  },

  @computed("model.query_plan")
  queryPlanHtml(queryPlan) {
    let output = `<pre class="badge-query-plan">`;

    queryPlan.forEach(linehash => {
      output += escapeExpression(linehash["QUERY PLAN"]);
      output += "<br>";
    });

    output += "</pre>";
    return output;
  },

  processedSample: map("model.sample", grant => {
    let i18nKey = "admin.badges.preview.grant.with";
    const i18nParams = { username: escapeExpression(grant.username) };

    if (grant.post_id) {
      i18nKey += "_post";
      i18nParams.link = `<a href="/p/${grant.post_id}" data-auto-route="true">
        ${Handlebars.Utils.escapeExpression(grant.title)}
      </a>`;
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
