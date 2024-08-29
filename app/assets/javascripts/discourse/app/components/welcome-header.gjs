const WelcomeHeader = <template>
  <div class="login-welcome-header" ...attributes>
    <h1 class="login-title">{{@subheader}}</h1>
    {{yield}}
  </div>
</template>;

export default WelcomeHeader;
