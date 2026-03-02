/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { tagName } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
import ProductItem from "./product-item";

@tagName("")
export default class ProductList extends Component {
  @computed("products")
  get emptyProducts() {
    return isEmpty(this.products);
  }

  <template>
    <div class="product-list" ...attributes>
      {{#if this.emptyProducts}}
        <p>{{i18n "discourse_subscriptions.subscribe.no_products"}}</p>
      {{else}}
        {{#each this.products as |product|}}
          <ProductItem @product={{product}} @isLoggedIn={{this.isLoggedIn}} />
        {{/each}}
      {{/if}}
    </div>
  </template>
}
