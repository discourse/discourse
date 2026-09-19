import AdSlot from "../../components/ad-slot";

const DiscourseAdplugin = <template>
  <span class="discovery-list-container-top-outlet discourse-adplugin">
    <AdSlot
      @category={{@outletArgs.category.slug}}
      @placement="topic-list-top"
    />
  </span>
</template>;

export default DiscourseAdplugin;
