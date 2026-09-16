import AiLlmsListEditor from "../../../../components/ai-llms-list-editor";

export default <template>
  <AiLlmsListEditor
    @currentLlm={{@controller.model}}
    @llms={{@controller.allLlms}}
  />
</template>
