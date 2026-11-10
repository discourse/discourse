import AiLogs from "../../../components/ai-logs.gjs";

export default <template>
  <AiLogs
    @model={{@controller.model.data}}
    @queryParams={{@controller.model.queryParams}}
  />
</template>
