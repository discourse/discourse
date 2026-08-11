import AdminMcp from "discourse/admin/components/admin-mcp";

export default <template>
  <AdminMcp @section="client-detail" @model={{@model}} />
</template>
