import { iconHTML } from "discourse-common/lib/icon-library";
import { bufferedRender } from "discourse-common/lib/buffered-render";

export default Ember.Component.extend(
  bufferedRender({
    classNameBindings: [":btn-group", "hidden"],
    rerenderTriggers: ["text", "longDescription"],

    _bindClick: function() {
      // If there's a click handler, call it
      if (this.clicked) {
        const self = this;
        this.$().on("click.dropdown-button", "ul li", function(e) {
          e.preventDefault();
          if ($(e.currentTarget).data("id") !== self.get("activeItem")) {
            self.clicked($(e.currentTarget).data("id"));
          }
          self.$(".dropdown-toggle").dropdown("toggle");
          return false;
        });
      }
    }.on("didInsertElement"),

    _unbindClick: function() {
      this.$().off("click.dropdown-button", "ul li");
    }.on("willDestroyElement"),

    buildBuffer(buffer) {
      const title = this.get("title");
      if (title) {
        buffer.push("<h4 class='title'>" + title + "</h4>");
      }

      buffer.push(
        `<button class='btn standard dropdown-toggle ${this.get(
          "buttonExtraClasses"
        ) || ""}' data-toggle='dropdown'>${this.get("text")}</button>`
      );
      buffer.push("<ul class='dropdown-menu'>");

      const contents = this.get("dropDownContent");
      if (contents) {
        const self = this;
        contents.forEach(function(row) {
          const id = row.id,
            className = self.get("activeItem") === id ? "disabled" : "";

          buffer.push(
            '<li data-id="' + id + '" class="' + className + '"><a href>'
          );

          if (row.icon) {
            let iconClass = "icon";
            if (row.iconClass) {
              iconClass += ` ${row.iconClass}`;
            }
            buffer.push(
              iconHTML(row.icon, { tagName: "span", class: iconClass })
            );
          }

          buffer.push("<div><span class='title'>" + row.title + "</span>");
          buffer.push("<span>" + row.description + "</span></div>");
          buffer.push("</a></li>");
        });
      }

      buffer.push("</ul>");

      const desc = this.get("longDescription");
      if (desc) {
        buffer.push("<p>");
        buffer.push(desc);
        buffer.push("</p>");
      }
    }
  })
);
