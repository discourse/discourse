import { isEmpty } from "@ember/utils";

export function cakeday(date) {
  return !isEmpty(date) && isSameDay(date, { anniversary: true });
}

export function birthday(date) {
  return !isEmpty(date) && isSameDay(date);
}

export function cakedayTitle(user, currentUser) {
  if (user.id === currentUser?.id) {
    return "user.anniversary.user_title";
  } else {
    return "user.anniversary.title";
  }
}

export function birthdayTitle(user, currentUser) {
  if (user.id === currentUser?.id) {
    return "user.date_of_birth.user_title";
  } else {
    return "user.date_of_birth.title";
  }
}

function isSameDay(dateString, opts) {
  const now = moment();
  const date = moment(dateString);

  if (opts?.anniversary) {
    if (now.format("YYYY") <= date.format("YYYY")) {
      return false;
    }
  }

  return now.format("MMDD") === date.format("MMDD");
}
