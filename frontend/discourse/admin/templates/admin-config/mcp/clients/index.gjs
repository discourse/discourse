import AdminMcp from "discourse/admin/components/admin-mcp";

export default <template>
  <AdminMcp @section="clients" @model={{@model}} />
</template>
