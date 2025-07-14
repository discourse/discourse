import Component from "@ember/component";
import { isEmpty } from "@ember/utils";
import { classNames } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import ProductItem from "./product-item";

@classNames("product-list")
export default class ProductList extends Component {
  @discourseComputed("products")
  emptyProducts(products) {
    return isEmpty(products);
  }

  <template>
    {{#if this.emptyProducts}}
      <p>{{i18n "discourse_subscriptions.subscribe.no_products"}}</p>
    {{else}}
      {{#each this.products as |product|}}
        <ProductItem @product={{product}} @isLoggedIn={{this.isLoggedIn}} />
      {{/each}}
    {{/if}}
  </template>
}
