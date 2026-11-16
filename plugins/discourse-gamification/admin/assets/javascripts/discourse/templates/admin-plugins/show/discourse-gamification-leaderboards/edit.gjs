import AdminEditLeaderboard from "discourse/plugins/discourse-gamification/admin/components/admin-edit-leaderboard";

export default <template>
  <div class="admin-detail">
    <AdminEditLeaderboard @leaderboard={{@model}} />
  </div>
</template>
