import AdSlot from "../../components/ad-slot";

const DiscourseAdplugin = <template>
  <div class="topic-above-post-stream-outlet discourse-adplugin">
    <AdSlot
      @category={{@outletArgs.model.category.slug}}
      @placement="topic-above-post-stream"
    />
  </div>
</template>;

export default DiscourseAdplugin;
