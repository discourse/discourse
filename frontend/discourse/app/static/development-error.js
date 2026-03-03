let dialogContent;

function setupErrorDialog() {
  const style = document.createElement("style");
  style.innerHTML = `
          #discourse-error-dialog {
            --error-color: #e04e39;

            background: light-dark(var(--error-color), #1e1e1e);
            border-radius: 16px;
            border: 1px solid light-dark(var(--error-color), #2a2a2a);
            box-shadow: 0 8px 16px 8px light-dark(#aaa, #111);
            color: light-dark(#fff, var(--error-color));
            display: flex;
            flex-direction: column;
            font-family: monospace;
            font-size: 13px;
            overflow: hidden;
            padding: 0;
            max-height: 90vh;

            &::before {
              background: #111 linear-gradient(-45deg, transparent 6px, var(--error-color) 6px, var(--error-color) 12px, transparent 12px);
              background-position: 4px;
              background-repeat: repeat-x;
              background-size: 18px 8px;
              content: "";
              display: block;
              height: 8px;
              width: 100%;
            }

            > div {
              align-items: center;
              display: flex;
              flex-wrap: wrap;
              margin: 16px 16px 0;
            }

            h1 {
              flex-grow: 1;
              font-family: system-ui, sans-serif;
              font-size: 28px;
            }

            img {
              height: 100px;
            }

            ul {
              margin: 0;
              overflow-y: scroll;
            }

            li {
              background: #0004;
              border-radius: 8px;
              list-style: none;
              margin: 0 16px 16px;
              padding: 16px 16px 32px;
            }
          }
        `;
  document.body.append(style);

  const dialog = document.createElement("dialog");
  dialog.id = "discourse-error-dialog";

  const heading = document.createElement("div");
  const title = document.createElement("h1");
  title.innerText = "Plugin Error";
  heading.append(title);

  const tomster = document.createElement("img");
  tomster.src = "images/fishy-tomster.webp";
  heading.append(tomster);

  dialog.append(heading);

  dialogContent = document.createElement("ul");
  dialog.append(dialogContent);

  document.body.append(dialog);
  dialog.showModal();
}

export function addError(error, pluginName, path) {
  if (!dialogContent) {
    setupErrorDialog();
  }

  const errorElement = document.createElement("li");
  errorElement.innerText += `❌ Failed to load plugin ${pluginName} from ${path}\n${error.message}`;
  dialogContent.append(errorElement);
}
