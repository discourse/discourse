import AiLlmsListEditor from "../../../../components/ai-llms-list-editor";

export default <template>
  <AiLlmsListEditor
    @llms={{@controller.allLlms}}
    @currentLlm={{@controller.model}}
  />
</template>
