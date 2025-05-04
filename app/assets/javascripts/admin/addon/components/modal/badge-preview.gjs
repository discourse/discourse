import Component from "@glimmer/component";
import DModal from "discourse/components/d-modal";
import icon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
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

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "admin.badges.preview.modal_title"}}
      class="badge-query-preview"
    >
      <:body>
        {{#if @model.badge.errors}}
          <p class="error-header">
            {{i18n "admin.badges.preview.sql_error_header"}}
          </p>
          <pre class="badge-errors">{{@model.badge.errors}}</pre>
        {{else}}
          <p class="grant-count">
            {{#if @model.badge.grant_count}}
              {{htmlSafe
                (i18n
                  "admin.badges.preview.grant_count"
                  count=@model.badge.grant_count
                )
              }}
            {{else}}
              {{htmlSafe (i18n "admin.badges.preview.no_grant_count")}}
            {{/if}}
          </p>

          {{#if this.countWarning}}
            <div class="count-warning">
              <p class="heading">
                {{icon "triangle-exclamation"}}
                {{i18n "admin.badges.preview.bad_count_warning.header"}}
              </p>
              <p class="body">
                {{i18n "admin.badges.preview.bad_count_warning.text"}}
              </p>
            </div>
          {{/if}}

          {{#if @model.badge.sample}}
            <p class="sample">
              {{i18n "admin.badges.preview.sample"}}
            </p>
            <ul>
              {{#each this.processedSample as |html|}}
                <li>{{htmlSafe html}}</li>
              {{/each}}
            </ul>
          {{/if}}

          {{#if this.hasQueryPlan}}
            <div class="badge-query-plan">
              {{htmlSafe this.queryPlanHtml}}
            </div>
          {{/if}}
        {{/if}}
      </:body>
    </DModal>
  </template>
}
