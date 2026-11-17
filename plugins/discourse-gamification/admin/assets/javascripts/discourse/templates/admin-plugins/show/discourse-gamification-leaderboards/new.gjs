import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import BackButton from "discourse/components/back-button";
import AdminCreateLeaderboard from "discourse/plugins/discourse-gamification/admin/components/admin-create-leaderboard";

export default <template>
  <div class="admin-detail">
    <BackButton
      @label="gamification.back_to_leaderboards"
      @route="adminPlugins.show.discourse-gamification-leaderboards"
    />

    <AdminConfigAreaCard @heading="gamification.leaderboard.new">
      <:content>
        <AdminCreateLeaderboard />
      </:content>
    </AdminConfigAreaCard>
  </div>
</template>
