# frozen_string_literal: true

RSpec.describe Onebox::Engine::LoomOnebox do
  it "returns the right HTML markup for the onebox" do
    expect(
      Onebox
        .preview(
          "https://www.loom.com/share/c9695e5dc084496c80b7d7516d2a569a?sid=e1279914-ecaa-4faf-afa8-89cbab488240",
        )
        .to_s
        .chomp,
    ).to eq(
      '<iframe class="loom-onebox" src="https://www.loom.com/embed/c9695e5dc084496c80b7d7516d2a569a?sid=e1279914-ecaa-4faf-afa8-89cbab488240" frameborder="0" allowfullscreen="" seamless="seamless" sandbox="allow-same-origin allow-scripts allow-forms allow-popups allow-popups-to-escape-sandbox allow-presentation"></iframe>',
    )
  end
end
