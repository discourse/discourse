import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";

const UserListInput = <template>
  <@field.Custom id={{@field.id}}>
    <EmailGroupUserChooser
      @value={{@field.value}}
      @onChange={{@field.set}}
      name={{@info.identifier}}
    />
  </@field.Custom>
</template>;

export default UserListInput;
