import BoardsPage from "../components/boards-page";

export default <template>
  <BoardsPage
    @boards={{@controller.model}}
    @canManageBoards={{@controller.currentUser.can_manage_boards}}
  />
</template>
