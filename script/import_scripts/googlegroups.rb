require 'fileutils'

# run this script INSIDE your Discourse Docker container
# to get into the Docker container:
# * SSH into your server
# * then cd /var/discourse
# * then ./launcher enter app

class ImportScripts::GoogleGroup < ImportScripts::Base

  def initialize(google_group_name)
    @google_group_name = google_group_name
    setup_google_group
  end

  def execute
    scrape_google_group_to_mbox
    install_dependencies
    import_mbox_to_discourse
  end

  # a valid cookie file called cookies.txt from google groups is expected in the /tmp folder
  def setup_google_group
    ENV['_GROUP'] = @google_group_name
    ENV['_WGET_OPTIONS'] = "--load-cookies /tmp/cookies.txt --keep-session-cookies"
    puts "######## Your Google Group name is #{@google_group_name}"
    puts "######## I'm expecting the Google Group URL to be https://groups.google.com/forum/#!forum/#{@google_group_name}"
  end

  # scrape content of the Google Group using https://github.com/icy/google-group-crawler
  # do everything in /tmp/
  def scrape_google_group_to_mbox
    FileUtils.rm_rf("/tmp/google-group-crawler") # idempotent
    system 'echo "######## Clone the Google Group Crawler from icy"'
    system 'git clone https://github.com/icy/google-group-crawler /tmp/google-group-crawler'
    # perform the scrape
    Dir.chdir '/tmp/google-group-crawler/' do
      system 'chmod +x ./crawler.sh'
      system 'echo "######## Start the first pass collection of topics"'
      system './crawler.sh -sh > wget.sh'
      system 'chmod +x ./wget.sh'
      system 'echo "######## Iterate through topics to get messages"'
      system './wget.sh'
      system "chmod -R 777 #{@google_group_name}"
      #system('chmod 777 member.csv'
    end
  end

  # mbox.rb requires sqlite3
  def install_dependencies
    system 'echo "######## Sqlite3 and libsqlite3-dev are required for the migration script"'
    system 'apt install -y sqlite3 libsqlite3-dev'
    system 'echo "######## Sqlite3 gem is required for the migration script"'
    system 'gem install sqlite3'
  end

  # import mbox data to Discourse using /script/import_scripts/mbox.rb which is part of Discourse
  def import_mbox_to_discourse
    #rename folder 'mbox' in the scrape data to 'messages' so that mbox.rb will work
    Dir.chdir "/tmp/google-group-crawler/#{@google_group_name}" do
      FileUtils.mv mbox messages
    end
    system 'su discourse'
    system 'RAILS_ENV=production ruby ./mbox.rb'
  end

end
