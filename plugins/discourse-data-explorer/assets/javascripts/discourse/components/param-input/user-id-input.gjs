import { hash } from "@ember/helper";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";

const UserIdInput = <template>
  <@Control id={{@field.id}}>
    <EmailGroupUserChooser
      name={{@info.identifier}}
      @onChange={{@field.set}}
      @options={{hash maximum=1}}
      @value={{@field.value}}
    />
  </@Control>
</template>;

export default UserIdInput;
