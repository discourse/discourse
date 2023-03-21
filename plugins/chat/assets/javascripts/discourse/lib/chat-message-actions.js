export default class ChatMessageActions {
  livePanel = null;
  currentUser = null;

  constructor(livePanel, currentUser) {
    this.livePanel = livePanel;
    this.currentUser = currentUser;
  }
}
