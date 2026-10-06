import AdSlot from "./ad-slot";

const PostBottomAd = <template>
  <AdSlot
    @category={{@model.topic.category.slug}}
    @placement="post-bottom"
    @postNumber={{@model.post_number}}
  />
</template>;

export default PostBottomAd;
