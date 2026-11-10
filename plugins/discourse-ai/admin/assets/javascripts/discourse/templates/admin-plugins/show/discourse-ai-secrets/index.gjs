import AiSecretsListEditor from "../../../../components/ai-secrets-list-editor.gjs";

export default <template>
  <AiSecretsListEditor @secrets={{@controller.model}} />
</template>
