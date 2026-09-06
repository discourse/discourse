import AiUsage from "../../../components/ai-usage";

export default <template>
  <AiUsage
    @model={{@controller.model.data}}
    @queryParams={{@controller.model.queryParams}}
  />
</template>
