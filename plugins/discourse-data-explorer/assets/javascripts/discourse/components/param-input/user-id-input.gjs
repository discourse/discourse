import { hash } from "@ember/helper";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";

const UserIdInput = <template>
  <@field.Custom id={{@field.id}}>
    <EmailGroupUserChooser
      @value={{@field.value}}
      @options={{hash maximum=1}}
      @onChange={{@field.set}}
      name={{@info.identifier}}
    />
  </@field.Custom>
</template>;

export default UserIdInput;
