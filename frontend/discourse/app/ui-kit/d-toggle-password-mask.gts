import type { TOC } from "@ember/component/template-only";
import DButton from "discourse/ui-kit/d-button";

interface DTogglePasswordMaskSignature {
  Args: {
    /** Whether the password is masked. The button offers the opposite. */
    maskPassword?: boolean;

    /** Toggles the mask. Called when the button is pressed. */
    togglePasswordMask: () => void;
  };
}

const DTogglePasswordMask: TOC<DTogglePasswordMaskSignature> = <template>
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
