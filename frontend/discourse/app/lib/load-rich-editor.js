export default async function loadRichEditor() {
  return (
    await import("discourse/static/prosemirror/components/prosemirror-editor")
  ).default;
}
