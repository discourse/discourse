import AdSlot from "../../components/ad-slot";

const DiscourseAdplugin = <template>
  <div class="above-site-header-outlet discourse-adplugin">
    <AdSlot
      @category={{@outletArgs.category.slug}}
      @placement="above-site-header"
    />
  </div>
</template>;

export default DiscourseAdplugin;
