import Component from "@ember/component";
import { LinkTo } from "@ember/routing";
import { classNames } from "@ember-decorators/component";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";

@classNames("product")
export default class ProductItem extends Component {
  <template>
    <h2>{{this.product.name}}</h2>

    <p class="product-description">
      {{htmlSafe this.product.description}}
    </p>

    {{#if this.isLoggedIn}}
      <div class="product-purchase">
        {{#if this.product.repurchaseable}}
          <LinkTo
            @route="subscribe.show"
            @model={{this.product.id}}
            class="btn btn-primary"
          >
            {{i18n "discourse_subscriptions.subscribe.title"}}
          </LinkTo>

          {{#if this.product.subscribed}}
            <LinkTo
              @route="user.billing.subscriptions"
              @model={{this.currentUser.username}}
              class="billing-link"
            >
              {{i18n "discourse_subscriptions.subscribe.view_past"}}
            </LinkTo>
          {{/if}}
        {{else}}
          {{#if this.product.subscribed}}
            <span class="purchased">
              &#x2713;
              {{i18n "discourse_subscriptions.subscribe.purchased"}}
            </span>

            <LinkTo
              @route="user.billing.subscriptions"
              @model={{this.currentUser.username}}
              class="billing-link"
            >
              {{i18n "discourse_subscriptions.subscribe.go_to_billing"}}
            </LinkTo>
          {{else}}
            <LinkTo
              @route="subscribe.show"
              @model={{this.product.id}}
              @disabled={{this.product.subscribed}}
              class="btn btn-primary"
            >
              {{i18n "discourse_subscriptions.subscribe.title"}}
            </LinkTo>
          {{/if}}
        {{/if}}
      </div>
    {{/if}}
  </template>
}
