/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";

@tagName("")
export default class ProductItem extends Component {
  <template>
    <div class="product" ...attributes>
      <h2>{{this.product.name}}</h2>

      <p class="product-description">
        {{trustHTML this.product.description}}
      </p>

      {{#if this.isLoggedIn}}
        <div class="product-purchase">
          {{#if this.product.repurchaseable}}
            <LinkTo
              class="btn btn-primary"
              @model={{this.product.id}}
              @route="subscribe.show"
            >
              {{i18n "discourse_subscriptions.subscribe.title"}}
            </LinkTo>

            {{#if this.product.subscribed}}
              <LinkTo
                class="billing-link"
                @model={{this.currentUser.username}}
                @route="user.billing.subscriptions"
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
                class="billing-link"
                @model={{this.currentUser.username}}
                @route="user.billing.subscriptions"
              >
                {{i18n "discourse_subscriptions.subscribe.go_to_billing"}}
              </LinkTo>
            {{else}}
              <LinkTo
                class="btn btn-primary"
                @disabled={{this.product.subscribed}}
                @model={{this.product.id}}
                @route="subscribe.show"
              >
                {{i18n "discourse_subscriptions.subscribe.title"}}
              </LinkTo>
            {{/if}}
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}
