import Component from "@glimmer/component";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class BadgePreview extends Component {
  get processedSample() {
    return this.args.model.badge.sample.map((grant) => {
      let i18nKey = "admin.badges.preview.grant.with";
      const i18nParams = { username: escapeExpression(grant.username) };

      if (grant.post_id) {
        i18nKey += "_post";
        i18nParams.link = `<a href="/p/${grant.post_id}" data-auto-route="true">
          ${escapeExpression(grant.title)}
        </a>`;
      }

      if (grant.granted_at) {
        i18nKey += "_time";
        i18nParams.time = escapeExpression(
          moment(grant.granted_at).format(i18n("dates.long_with_year"))
        );
      }

      return i18n(i18nKey, i18nParams);
    });
  }

  get countWarning() {
    if (this.args.model.badge.grant_count <= 10) {
      return (
        this.args.model.badge.sample.length !==
        this.args.model.badge.grant_count
      );
    } else {
      return this.args.model.badge.sample?.length !== 10;
    }
  }

  get hasQueryPlan() {
    return !!this.args.model.badge.query_plan;
  }

  get queryPlanHtml() {
    let output = `<pre>`;
    this.args.model.badge.query_plan.forEach((linehash) => {
      output += escapeExpression(linehash["QUERY PLAN"]);
      output += "<br>";
    });
    output += "</pre>";
    return output;
  }
}
