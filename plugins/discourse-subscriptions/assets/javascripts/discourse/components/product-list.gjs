import Component from "@glimmer/component";
import { isEmpty } from "@ember/utils";
import { i18n } from "discourse-i18n";
import ProductItem from "./product-item";

export default class ProductList extends Component {
  get emptyProducts() {
    return isEmpty(this.args.products);
  }

  <template>
    <div class="product-list" ...attributes>
      {{#if this.emptyProducts}}
        <p>{{i18n "discourse_subscriptions.subscribe.no_products"}}</p>
      {{else}}
        {{#each @products as |product|}}
          <ProductItem @isLoggedIn={{@isLoggedIn}} @product={{product}} />
        {{/each}}
      {{/if}}
    </div>
  </template>
}
