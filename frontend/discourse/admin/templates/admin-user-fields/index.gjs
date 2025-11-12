import UserFieldsList from "discourse/admin/components/admin-config-areas/user-fields-list";

export default <template>
  <UserFieldsList @userFields={{@controller.model}} />
</template>
