import avatar from "discourse/helpers/avatar";

const AssignedTo = <template>
  <div class="assigned-to-user">
    {{avatar @user imageSize="small"}}

    <span class="assigned-username">
      {{@user.username}}
    </span>

    {{yield}}
  </div>
</template>;

export default AssignedTo;
