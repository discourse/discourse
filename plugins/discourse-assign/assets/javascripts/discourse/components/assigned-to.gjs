import dAvatar from "discourse/ui-kit/helpers/d-avatar";

const AssignedTo = <template>
  <div class="assigned-to-user">
    {{dAvatar @user imageSize="small"}}

    <span class="assigned-username">
      {{@user.username}}
    </span>

    {{yield}}
  </div>
</template>;

export default AssignedTo;
