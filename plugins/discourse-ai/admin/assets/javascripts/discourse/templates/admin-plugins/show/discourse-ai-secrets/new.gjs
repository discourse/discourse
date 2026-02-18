import AiSecretsListEditor from "../../../../components/ai-secrets-list-editor";

export default <template>
  <AiSecretsListEditor
    @secrets={{@controller.allSecrets}}
    @currentSecret={{@controller.model}}
  />
</template>
