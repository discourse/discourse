<div class="container">
  <h2>{{i18n "login.to_continue"}}</h2>

  <p style="margin-top: 1em">{{i18n "login.preferences"}}</p>

  <DButton
    @action={{route-action "showLogin"}}
    @label="log_in"
    class="btn-primary"
  />
</div>