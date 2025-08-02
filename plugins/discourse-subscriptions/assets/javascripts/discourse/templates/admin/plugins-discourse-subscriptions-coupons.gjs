import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import CreateCouponForm from "../../components/create-coupon-form";

export default RouteTemplate(
  <template>
    {{#if @controller.model.unconfigured}}
      <p>{{i18n "discourse_subscriptions.admin.unconfigured"}}</p>
      <p>
        <a href="https://meta.discourse.org/t/discourse-subscriptions/140818/">
          {{i18n "discourse_subscriptions.admin.on_meta"}}
        </a>
      </p>
    {{else}}
      {{#if @controller.model}}
        <table class="table discourse-patrons-table">
          <thead>
            <th>{{i18n "discourse_subscriptions.admin.coupons.code"}}</th>
            <th>{{i18n "discourse_subscriptions.admin.coupons.discount"}}</th>
            <th>{{i18n
                "discourse_subscriptions.admin.coupons.times_redeemed"
              }}</th>
            <th>{{i18n "discourse_subscriptions.admin.coupons.active"}}</th>
            <th>{{i18n "discourse_subscriptions.admin.coupons.actions"}}</th>
          </thead>
          <tbody>
            {{#each @controller.model as |coupon|}}
              <tr>
                <td>{{coupon.code}}</td>
                <td>{{coupon.discount}}</td>
                <td>{{coupon.times_redeemed}}</td>
                <td>
                  <Input
                    @type="checkbox"
                    @checked={{coupon.active}}
                    {{on "click" (fn @controller.toggleActive coupon)}}
                  />
                </td>
                <td>
                  <DButton
                    @action={{fn @controller.deleteCoupon coupon}}
                    @icon="trash-can"
                    class="btn-danger btn btn-icon btn-no-text"
                  />
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{/if}}

      {{#unless @controller.creating}}
        <DButton
          @action={{@controller.openCreateForm}}
          @label="discourse_subscriptions.admin.coupons.create"
          @title="discourse_subscriptions.admin.coupons.create"
          @icon="plus"
          class="btn btn-icon btn-primary create-coupon"
        />
      {{/unless}}

      {{#if @controller.creating}}
        <CreateCouponForm
          @cancel={{@controller.closeCreateForm}}
          @create={{@controller.createNewCoupon}}
        />
      {{/if}}
    {{/if}}
  </template>
);
