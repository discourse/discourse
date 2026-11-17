import LoginRequired from "../../components/login-required.gjs";
import ProductList from "../../components/product-list.gjs";

export default <template>
  {{#unless @controller.isLoggedIn}}
    <LoginRequired />
  {{/unless}}

  <ProductList
    @isLoggedIn={{@controller.isLoggedIn}}
    @products={{@controller.model}}
  />
</template>
