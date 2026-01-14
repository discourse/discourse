const WelcomeHeader = <template>
  <div class="login-welcome-header" ...attributes>
    <h1 class="login-title">{{@header}}</h1>
    {{yield}}
  </div>
</template>;

export default WelcomeHeader;
