import About from "discourse/admin/components/admin-config-areas/about";

export default <template>
  <About @data={{@controller.model.site_settings}} />
</template>
