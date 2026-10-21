import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { i18n } from "discourse-i18n";

export default class ProductItem extends Component {
  @service currentUser;

  <template>
    <div class="product" ...attributes>
      <h2>{{@product.name}}</h2>

      <p class="product-description">
        {{trustHTML @product.description}}
      </p>

      {{#if @isLoggedIn}}
        <div class="product-purchase">
          {{#if @product.repurchaseable}}
            <LinkTo
              class="btn btn-primary"
              @model={{@product.id}}
              @route="subscribe.show"
            >
              {{i18n "discourse_subscriptions.subscribe.title"}}
            </LinkTo>

            {{#if @product.subscribed}}
              <LinkTo
                class="billing-link"
                @model={{this.currentUser.username}}
                @route="user.billing.subscriptions"
              >
                {{i18n "discourse_subscriptions.subscribe.view_past"}}
              </LinkTo>
            {{/if}}
          {{else}}
            {{#if @product.subscribed}}
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
                @disabled={{@product.subscribed}}
                @model={{@product.id}}
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
