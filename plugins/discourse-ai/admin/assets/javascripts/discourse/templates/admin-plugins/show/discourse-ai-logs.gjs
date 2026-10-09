import AiLogs from "../../../components/ai-logs";

export default <template>
  <AiLogs
    @model={{@controller.model.data}}
    @queryParams={{@controller.model.queryParams}}
  />
</template>
