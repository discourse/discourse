import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";

const UserListInput = <template>
  <@Control id={{@field.id}}>
    <EmailGroupUserChooser
      @value={{@field.value}}
      @onChange={{@field.set}}
      name={{@info.identifier}}
    />
  </@Control>
</template>;

export default UserListInput;
