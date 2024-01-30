export default function tonableEmojiTitle(emoji, diversity) {
  if (!emoji.tonable || diversity === 1) {
    return `:${emoji.name}:`;
  }

  return `:${emoji.name}:t${diversity}:`;
}
