module Onebox
  module Engine
    class GithubBlobOnebox
      include Engine
      include LayoutSupport
      include HTML

      matches do
        http
        maybe("www")
        domain("github")
        tld("com")
        anything
        with("/blob/")
      end

      private

      def data
        {
          link: link,
          domain: "https://www.github.com",
          badge: "g",
          title: raw.css(".final-path").inner_text,
          lines: raw.css("#files .file .info .mode + span").inner_text,
          file: raw.css("#files .file .blob-wrapper").inner_text
        }
      end
    end
  end
end
