# run this script INSIDE your Discourse Docker container
# to get into the Docker container:
# * SSH into your server
# * then cd /var/discourse
# * then ./launcher enter app

# mbox.rb requires sqlite3
def install_dependencies
  system 'echo "######## Sqlite3 and libsqlite3-dev are required for the migration script"'
  system 'apt install -y sqlite3 libsqlite3-dev'
  system 'echo "######## Sqlite3 gem is required for the migration script"'
  system 'gem install sqlite3'
end

def setup_google_group
  @google_group_name = ARGV[0]
  system "export _GROUP=#{@google_group_name}"
  system 'export _WGET_OPTIONS="--load-cookies cookies.txt --keep-session-cookies"'
  puts "######## Your Google Group name is #{@google_group_name}"
  puts "######## Google Group URL should be https://groups.google.com/forum/#!forum/#{@google_group_name}"
end

# scrape content of the Google Group using https://github.com/icy/google-group-crawler
# do everything in /tmp/
def scrape_google_group_to_mbox
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

# import mbox data to Discourse using /script/import_scripts/mbox.rb

# correct the imported users' email addresses (?)

# run the script
install_dependencies
setup_google_group
scrape_google_group_to_mbox
