import LoginRequired from "../components/login-required";

<template>
  <div class="container">
    {{#if @controller.currentUser}}
      {{@controller.pricingTable}}
    {{else}}
      <LoginRequired />
    {{/if}}
  </div>
</template>
