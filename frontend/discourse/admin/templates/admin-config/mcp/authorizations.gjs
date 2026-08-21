import AdminMcp from "discourse/admin/components/admin-mcp";

export default <template>
  <AdminMcp @section="authorizations" @model={{@model}} />
</template>
