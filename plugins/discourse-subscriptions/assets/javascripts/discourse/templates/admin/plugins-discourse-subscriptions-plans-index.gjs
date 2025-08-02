import { fn } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <table class="table discourse-patrons-table">
      <thead>
        <th>{{i18n "discourse_subscriptions.admin.plans.plan.plan_id"}}</th>
        <th>{{i18n
            "discourse_subscriptions.admin.plans.plan.nickname.title"
          }}</th>
        <th>{{i18n "discourse_subscriptions.admin.plans.plan.interval"}}</th>
        <th>{{i18n "discourse_subscriptions.admin.plans.plan.amount"}}</th>
        <th></th>
      </thead>
      <tbody>
        {{#each @controller.model as |plan|}}
          <tr>
            <td>{{plan.id}}</td>
            <td>{{plan.nickname}}</td>
            <td>{{plan.interval}}</td>
            <td>{{plan.unit_amount}}</td>
            <td class="td-right">
              <DButton
                @action={{fn @controller.editPlan plan.id}}
                @icon="far-pen-to-square"
                class="btn no-text btn-icon"
              />
              <DButton
                @action={{routeAction "destroyPlan"}}
                @actionParam={{plan}}
                @icon="trash-can"
                class="btn-danger btn no-text btn-icon"
              />
            </td>
          </tr>
        {{/each}}
      </tbody>
    </table>
  </template>
);
