import AdminPermalinkForm from "discourse/admin/components/admin-permalink-form";

export default <template>
  <AdminPermalinkForm @permalink={{@controller.model}} />
</template>
