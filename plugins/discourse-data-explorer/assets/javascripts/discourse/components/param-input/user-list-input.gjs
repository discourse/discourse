import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";

const UserListInput = <template>
  <@Control id={{@field.id}}>
    <EmailGroupUserChooser
      name={{@info.identifier}}
      @onChange={{@field.set}}
      @value={{@field.value}}
    />
  </@Control>
</template>;

export default UserListInput;
