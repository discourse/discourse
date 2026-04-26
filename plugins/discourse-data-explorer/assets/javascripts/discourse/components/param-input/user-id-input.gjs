import { hash } from "@ember/helper";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";

const UserIdInput = <template>
  <@Control id={{@field.id}}>
    <EmailGroupUserChooser
      @value={{@field.value}}
      @options={{hash maximum=1}}
      @onChange={{@field.set}}
      name={{@info.identifier}}
    />
  </@Control>
</template>;

export default UserIdInput;
