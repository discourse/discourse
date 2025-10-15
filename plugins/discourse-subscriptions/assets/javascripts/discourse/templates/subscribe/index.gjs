import LoginRequired from "../../components/login-required";
import ProductList from "../../components/product-list";

<template>
  {{#unless @controller.isLoggedIn}}
    <LoginRequired />
  {{/unless}}

  <ProductList
    @products={{@controller.model}}
    @isLoggedIn={{@controller.isLoggedIn}}
  />
</template>
