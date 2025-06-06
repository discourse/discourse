import DButton from "discourse/components/d-button";

const TogglePasswordMask = <template>
  <DButton
    @action={{@togglePasswordMask}}
    @icon={{if @maskPassword "far-eye" "far-eye-slash"}}
    @title={{if
      @maskPassword
      "login.show_password_title"
      "login.hide_password_title"
    }}
    class="btn-transparent toggle-password-mask"
  />
</template>;

export default TogglePasswordMask;
