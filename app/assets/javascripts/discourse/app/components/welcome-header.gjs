import { wavingHandURL } from "discourse/lib/waving-hand-url";

const WelcomeHeader = <template>
  <div class="login-welcome-header" ...attributes>
    <h1 class="login-title">{{@header}}</h1>
    <img src={{(wavingHandURL)}} alt="" class="waving-hand" />
    {{#if @subheader}}
      <p class="login-subheader">{{@subheader}}</p>
    {{/if}}
    {{yield}}
  </div>
</template>;

export default WelcomeHeader;
