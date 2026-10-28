import BlogDashboard from "../components/blog-dashboard.gjs";

export default <template>
  {{#if @model}}<BlogDashboard @model={{@model}} />{{/if}}
</template>
