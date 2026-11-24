# frozen_string_literal: true

RSpec.describe "System browser driver" do
  fab!(:user)

  it "types literal text and accepts keyboard shortcuts in the same action" do
    visit "/robots.txt"
    page.execute_script("document.body.innerHTML = '<label>Text <input></label>'")

    input = find_field("Text")
    input.send_keys("two + two", %i[shift left], "3")
    input.send_keys(:home, :shift, "a")

    expect(page).to have_field("Text", with: "Atwo + tw3")
  end

  it "clears the previous example's tabs, cookies, and storage" do
    sign_in(user)
    visit "/robots.txt"
    session_status = <<~JS
      const done = arguments[arguments.length - 1];
      fetch("/session/current.json").then((response) => done(response.status));
    JS
    expect(page.evaluate_async_script(session_status)).to eq(200)
    original = page.current_window
    popup = open_new_window
    page.execute_script(<<~JS)
      localStorage.setItem("driver-reset", "present");
      sessionStorage.setItem("driver-reset", "present");
      document.cookie = "driver-reset=present; path=/";
    JS

    Capybara.reset_sessions!

    expect(page.windows.size).to eq(1)
    expect([original, popup]).to all(be_closed)
    visit "/robots.txt"
    expect(page.evaluate_async_script(session_status)).to eq(404)
    expect(page.evaluate_script(<<~JS)).to eq([false, false, false])
      [
        localStorage.getItem("driver-reset") !== null,
        sessionStorage.getItem("driver-reset") !== null,
        document.cookie.includes("driver-reset=")
      ]
    JS
  end

  it "clears document history and persistent storage on reset" do
    visit "/robots.txt"
    initial_history_length = page.evaluate_script("history.length")
    visit "/robots.txt?probe=1"
    expect(page.evaluate_script("history.length")).to be > initial_history_length
    page.execute_script("window.name = 'driver-reset'")
    expect(page.evaluate_async_script(<<~JS)).to eq(true)
      const done = arguments[arguments.length - 1];
      const database = new Promise((resolve, reject) => {
        const request = indexedDB.open("driver-reset", 1);
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });

      Promise.all([caches.open("driver-reset"), database]).then(([, db]) => {
        window.resetProbe = db;
        done(true);
      }, (error) => done(String(error)));
    JS

    Capybara.reset_sessions!
    visit "/robots.txt"

    expect(page.evaluate_script("[history.length, window.name]")).to eq(
      [initial_history_length, ""],
    )
    expect(page.evaluate_async_script(<<~JS)).to eq([false, false])
      const done = arguments[arguments.length - 1];
      Promise.all([
        caches.has("driver-reset"),
        indexedDB.databases().then((databases) => databases.some((db) => db.name === "driver-reset"))
      ]).then(done, (error) => done(String(error)));
    JS
  end

  it "clears granted permissions on reset", browser_features: :browser_permissions do
    visit "/robots.txt"
    permission_state = <<~JS
      const done = arguments[arguments.length - 1];
      navigator.permissions.query({ name: "geolocation" }).then((permission) => done(permission.state));
    JS
    initial_state = page.evaluate_async_script(permission_state)
    page.driver.with_browser_page { |browser| browser.grant_permissions(["geolocation"]) }
    expect(page.evaluate_async_script(permission_state)).to eq("granted")

    Capybara.reset_sessions!
    visit "/robots.txt"

    expect(page.evaluate_async_script(permission_state)).to eq(initial_state)
  end

  it "removes downloaded files on reset", browser_features: :completed_downloads do
    visit "/robots.txt"
    page.execute_script(<<~JS)
      document.body.innerHTML = '<a href="/robots.txt" download="driver-reset.txt">Download</a>';
    JS

    download =
      page.driver.with_browser_page { |browser| browser.expect_download { click_link("Download") } }
    path = download.path
    expect(File.file?(path)).to eq(true)

    Capybara.reset_sessions!

    expect(File.exist?(path)).to eq(false)
  end

  it "discards a browser clock override on reset", browser_features: :browser_clock do
    time = Time.utc(2020, 1, 1)
    visit "/robots.txt"
    BrowserTime.freeze(page, time)
    expect(page.evaluate_script("Date.now()")).to be_within(10_000).of(time.to_i * 1_000)

    Capybara.reset_sessions!
    visit "/robots.txt"

    expect(page.evaluate_script("Date.now()")).to be_within(10_000).of(
      Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond),
    )
  end

  it "matches text in an ancestor selector and checks locator visibility" do
    visit "/robots.txt"
    page.execute_script(<<~JS)
      document.body.innerHTML = `
        <main>
          <section><span>Release \n notes</span><button>Read</button></section>
          <section><span>Other</span><button hidden>Hide</button></section>
        </main>
      `;
    JS

    expect(page.find("section:has-text('release notes') > button").text).to eq("Read")
    expect(
      locator("main").locator("section", hasText: "Release notes").locator("button"),
    ).to be_visible
    expect(locator("main").locator("section", hasText: "Other").locator("button")).to be_hidden
    expect(locator("main").locator("section", hasText: "Missing")).to be_hidden
  end

  it "evaluates signed zero as a number inside an array" do
    visit "/robots.txt"

    expect(page.evaluate_script("[-0, 0, -2]")).to eq([0, 0, -2])
  end

  it "can still read a file upload after the source file is removed" do
    visit "/robots.txt"
    page.execute_script("document.body.innerHTML = '<input type=file>'")

    Dir.mktmpdir do |directory|
      path = File.join(directory, "example.txt")
      File.write(path, "Selected file")
      find("input[type=file]").attach_file(path)
    end

    expect(page.evaluate_script("document.querySelector('input').files[0].text()")).to eq(
      "Selected file",
    )
  end

  it "types the final key in the field being filled when its input changes focus" do
    visit "/robots.txt"
    page.execute_script(<<~JS)
      document.body.innerHTML = '<input id="source"><input id="sink">';
      document.querySelector('#source').addEventListener('input', () => {
        document.querySelector('#sink').focus();
      }, { once: true });
    JS

    fill_in("source", with: "This is a test message!")

    expect(find_field("source").value).to include("!")
    expect(page).to have_field("sink", with: "")
  end

  it "reports browser console warnings and document errors" do
    visit "/robots.txt"

    with_logs do |logger|
      page.execute_script(<<~JS)
        console.warn('Browser diagnostic warning');
        setTimeout(() => { throw new Error('Browser diagnostic error'); });
      JS

      try_until_success do
        expect(logger.logs).to include(
          a_hash_including(level: "warn", message: "Browser diagnostic warning"),
          a_hash_including(
            source: "pageerror-api",
            message: a_string_including("Browser diagnostic error"),
            stack: a_string_matching(/\S/),
          ),
        )
      end
    end
  end
end
