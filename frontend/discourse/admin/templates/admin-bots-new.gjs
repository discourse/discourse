import AdminBotForm from "discourse/admin/components/admin-bot-form";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import BackButton from "discourse/components/back-button";

export default <template>
  <BackButton
    @label="admin.users.bots.back"
    @model="bots"
    @route="adminUsersList.show"
  />
  <div class="admin-config-area">
    <div class="admin-config-area__primary-content">
      <AdminConfigAreaCard
        @description="admin.users.bots.help"
        @heading="admin.users.bots.new"
      >
        <:content>
          <AdminBotForm
            @apiKeyScopes={{@model.apiKeyScopes}}
            @defaultTrustLevel={{@model.default_trust_level}}
            @nameRequired={{@model.name_required}}
          />
        </:content>
      </AdminConfigAreaCard>
    </div>
  </div>
</template>
