import AdSlot from "../../components/ad-slot";

const DiscourseAdplugin = <template>
  <div class="topic-above-post-stream-outlet discourse-adplugin">
    <AdSlot
      @placement="topic-above-post-stream"
      @category={{@outletArgs.model.category.slug}}
    />
  </div>
</template>;

export default DiscourseAdplugin;
