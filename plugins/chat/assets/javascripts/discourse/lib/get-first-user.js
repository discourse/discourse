export default function getFirstUsers(users, currentUser) {
  return users.sort((a, b) => {
    if (a.id === currentUser.id) {
      return 1;
    }
    if (b.id === currentUser.id) {
      return -1;
    }
    return 1;
  })[0];
}
