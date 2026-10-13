import LoginRequired from "../../components/login-required";
import ProductList from "../../components/product-list";

export default <template>
  {{#unless @controller.isLoggedIn}}
    <LoginRequired />
  {{/unless}}

  <ProductList
    @isLoggedIn={{@controller.isLoggedIn}}
    @products={{@controller.model}}
  />
</template>
