import DButton from "discourse/ui-kit/d-button";

const DTogglePasswordMask = <template>
  <DButton
    class="btn-transparent toggle-password-mask"
    @action={{@togglePasswordMask}}
    @icon={{if @maskPassword "far-eye" "far-eye-slash"}}
    @title={{if
      @maskPassword
      "login.show_password_title"
      "login.hide_password_title"
    }}
  />
</template>;

export default DTogglePasswordMask;
