import AiLlmsListEditor from "../../../../../discourse/components/ai-llms-list-editor";

export default <template>
  <AiLlmsListEditor
    @llms={{@controller.allLlms}}
    @currentLlm={{@controller.model}}
    @llmTemplate={{@controller.llmTemplate}}
  />
</template>
