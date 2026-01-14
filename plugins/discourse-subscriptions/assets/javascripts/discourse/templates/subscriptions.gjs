import LoginRequired from "../components/login-required";

export default <template>
  <div class="container">
    {{#if @controller.currentUser}}
      {{@controller.pricingTable}}
    {{else}}
      <LoginRequired />
    {{/if}}
  </div>
</template>
