require 'feedzirra'
require 'active_record'
#require 'database_configuration'
require 'timeout'

FEED_FETCH_AND_PARSE_TIMEOUT_IN_SECONDS = 180
FEED_UPDATE_TIMEOUT_IN_SECONDS = 60


class RssEntry < ActiveRecord::Base
  def self.add_entries_to_db_from_feed(feed, source)
    if not feed
      return 0
    end
    new_entry_count = 0
    feed.entries.each do |entry|
      #puts "  id=#{entry.id}:"
      #puts "    published_at=#{entry.published}"
      #puts "    title=#{entry.title}"
      #puts "    url=#{entry.url}"
      #puts "    summary=#{entry.summary}\n"
      unless exists? :guid => entry.id
        create!(
          :source => source,
          :name => entry.title,
          :summary => entry.summary,
          :url => entry.url,
          :published_at => entry.published,
          :guid => entry.id
        )
        new_entry_count += 1
      end
    end
    return new_entry_count
  end
end

class PodcastEntry < ActiveRecord::Base
  def self.add_entries_to_db_from_feed(feed, source)
    if not feed
      return 0
    end
    new_entry_count = 0
    feed.entries.each do |entry|
      #puts "  id=#{entry.id}:"
      #puts "    published_at=#{entry.published}"
      #puts "    title=#{entry.title}"
      #puts "    url=#{entry.url}"
      #puts "    summary=#{entry.summary}\n"
      unless exists? :guid => entry.id
        create!(
          :source => source,
          :name => entry.title,
          :summary => entry.summary,
          :url => entry.url,
          :published_at => entry.published,
          :guid => entry.id
        )
        new_entry_count += 1
      end
    end
    return new_entry_count
  end
end

class RssFeed < ActiveRecord::Base
  def self.update_feeds(current_feeds_map, new_feeds_map, feed_type = 'news')
    # TODO:  not deleting entries of deleted feeds, may be want to do it later 
    #   (but, this is not so bad because old entries will grow old and get deleted eventually)
    if(feed_type == 'podcast') 
      rss_feeds = PodcastFeed.find(:all)
    else
      rss_feeds = RssFeed.find(:all)
    end
    new_entry_count_total = 0
    rss_feeds.each do |rss_feed|
      #rss_feed.chomp!
      #fields = rss_feed.split(" ")
      #rss_feed_url = fields[0]
      #source = ""
      #if fields.length > 1
      #  source = fields[1..-1].join(" ")
      #end
      rssfeed_url = rss_feed.link
      source = rss_feed.title
      feed = nil
      if not current_feeds_map.include?(rssfeed_url)
        puts DateTime.now.to_s + ": Fetching entries from #{source}:<#{rssfeed_url}>:"
        begin
          Timeout::timeout(FEED_FETCH_AND_PARSE_TIMEOUT_IN_SECONDS) do
            feed = Feedzirra::Feed.fetch_and_parse(rssfeed_url)
          end
        rescue Timeout::Error => te
          puts DateTime.now.to_s + ": Feed fetch_and_parse timedout:(#{rssfeed_url}) aftr #{FEED_FETCH_AND_PARSE_TIMEOUT_IN_SECONDS}seconds: #{te}"
        rescue Exception => e
          puts DateTime.now.to_s + ": **** Exception while fetch_and_parse feed at <#{rssfeed_url}>: " +
            e.message.to_s + ": " + e.inspect.to_s
          puts e.backtrace  
        end
        if (feed==nil) or (feed == 0)
          new_feeds_map[rssfeed_url] = nil
          puts "  Feed returned 0 entries"
        else
          new_feeds_map[rssfeed_url] = feed
          if(feed_type == 'podcast') 
            new_entry_count = PodcastEntry.add_entries_to_db_from_feed(feed, source)
          else
            new_entry_count = RssEntry.add_entries_to_db_from_feed(feed, source)
          end
          puts "  Got entries from <#{rssfeed_url}: total #{feed.entries.count}: new #{new_entry_count}"
          new_entry_count_total += new_entry_count
        end
      else
        feed = current_feeds_map[rssfeed_url]
        updated_feed = nil
        puts DateTime.now.to_s + ": Updating entries from #{source}:<#{rssfeed_url}>:"
        begin
          Timeout::timeout(FEED_UPDATE_TIMEOUT_IN_SECONDS) do
            updated_feed = Feedzirra::Feed.update(feed)
          end
        rescue Timeout::Error => te
          puts DateTime.now.to_s + ": Feed update timedout:(#{rssfeed_url}) aftr #{FEED_UPDATE_TIMEOUT_IN_SECONDS}seconds: #{te}"
        rescue Exception => e
          puts DateTime.now.to_s + ": **** Exception while fetch_and_parse feed at <#{rssfeed_url}>: " +
            e.message.to_s + ": " + e.inspect.to_s
          puts e.backtrace  
        end
        if (updated_feed == nil) or (updated_feed == 0)
          new_feeds_map[rssfeed_url] = nil
          puts "  Feed returned 0 entries"
        else
          new_feeds_map[rssfeed_url] = updated_feed
          if(feed_type == 'podcast') 
            new_entry_count = PodcastEntry.add_entries_to_db_from_feed(updated_feed, source)
          else
            new_entry_count = RssEntry.add_entries_to_db_from_feed(updated_feed, source)
          end
          puts "  Updated entries from <#{rssfeed_url}: total #{updated_feed.entries.count}: new #{new_entry_count}"
          new_entry_count_total += new_entry_count
        end
      end
    end
    return new_entry_count_total
  end
end

class PodcastFeed < ActiveRecord::Base
  def self.update_feeds(current_feeds_map, new_feeds_map)
    return RssFeed.update_feeds(current_feeds_map, new_feeds_map, 'podcast')
  end
end

class Setting < ActiveRecord::Base
  @@CheckSettingsPeriodInSeconds = 5 
  @@UpdatePeriodInSeconds = (60*60)
  @@RefreshNow = 0
  @@ExitNow = 0
  def self.update_settings()
    settings = self.find(:all)
    #puts "Updating settings from db: #{settings.size} settings (not all printed below)" 
    settings.each do |setting|
      if setting.name == "CheckSettingsPeriodInSeconds"
        @@CheckSettingsPeriodInSeconds = setting.value.to_i
        #puts "#{setting.name}: #{setting.value}"
      end
      if setting.name == "UpdatePeriodInSeconds"
        @@UpdatePeriodInSeconds = setting.value.to_i
        #puts "#{setting.name}: #{setting.value}"
      end
      if setting.name == "RefreshNow"
        @@RefreshNow = setting.value.to_i
      end
      if setting.name == "ExitNow"
        @@ExitNow = setting.value.to_i
      end
    end
    #puts "\n"
  end
  def self.CheckSettingsPeriod()
    return @@CheckSettingsPeriodInSeconds
  end
  def self.UpdatePeriod()
    return @@UpdatePeriodInSeconds
  end
  def self.RefreshNow()
    return @@RefreshNow
  end
  def self.ExitNow()
    return @@ExitNow
  end
end

class VideoEntry < ActiveRecord::Base
end


ActiveRecord::Base.establish_connection(YAML::load(File.open('db/config/database.yml')))

#parameters_dir = "Stemlete"
#rss_feeds_filename = "rss_feeds.txt"
#
#rss_feeds_file = File.open(parameters_dir+"/" + rss_feeds_filename, "r")
#if not rss_feeds_file
#  puts "Fatal error: Rss feeds file <" + parameters_dir+"/" + rss_feeds_filename + "> not found"
#  exit
#end
#rss_feeds = rss_feeds_file.readlines()
#rss_feeds_file.close()

Setting.update_settings()

feeds_map = Hash.new
new_feeds_map = Hash.new
new_entry_count = 0
podcast_feeds_map = Hash.new
new_podcast_feeds_map = Hash.new
new_podcast_entry_count = 0
begin
  #new_entry_count = RssFeed.update_feeds(feeds_map, new_feeds_map)
  new_podcast_entry_count = PodcastFeed.update_feeds(podcast_feeds_map, 
    new_podcast_feeds_map)
rescue Exception => e
    puts DateTime.now.to_s + ": **** Exception while updating feeds: " +
      e.message.to_s + ": " + e.inspect.to_s
    puts e.backtrace  
end
feeds_map = new_feeds_map
podcast_feeds_map = new_podcast_feeds_map
puts "\n#{DateTime.now}: **********Added first fetch total " + 
  new_entry_count.to_s + " new news entries and total " + 
  new_podcast_entry_count.to_s + " new podcast entries to db"


entries = RssEntry.find(:all)
puts "\n#{DateTime.now}:**********Initial entries: count in database: " + entries.length.to_s + " entries"
podcast_entries = PodcastEntry.find(:all)
puts "\n#{DateTime.now}:**********Initial podcast entries: count in database: " + podcast_entries.length.to_s + " entries"

#entries.each do | entry |
#  puts "id=#{entry.guid}:"
#  puts "  published_at=#{entry.published_at}"
#  puts "  title=#{entry.name}"
#  puts "  source=#{entry.source}, url=#{entry.url}"
#  puts "  summary=#{entry.summary}\n"
#end


duration_from_last_update = 0
while (true)
  sleep(Setting.CheckSettingsPeriod())
  duration_from_last_update += Setting.CheckSettingsPeriod()
  # puts "#{DateTime.now}: checking settings"
  Setting.update_settings()
  if(Setting.ExitNow() != 0)
    puts "#{DateTime.now}: Exiting..."
    exit 0
  end
  if( Setting.RefreshNow() != 0) or 
        (duration_from_last_update >= Setting.UpdatePeriod())
    puts "#{DateTime.now}: Updating now: duration_from_last_update=#{duration_from_last_update}seconds" 
    new_feeds_map = Hash.new
    begin
      new_entry_count = RssFeed.update_feeds(feeds_map, new_feeds_map)
      new_podcast_entry_count = PodcastFeed.update_feeds(feeds_map, new_feeds_map)
    rescue Exception => e
        puts DateTime.now.to_s + ": **** Exception while updating feeds: " +
          e.message.to_s + ": " + e.inspect.to_s
        puts e.backtrace  
    end
    feeds_map = new_feeds_map
    puts "\n#{DateTime.now}: **********Added total " + 
      new_entry_count.to_s + " new news entries and total " + 
      new_podcast_entry_count.to_s + " new podcast entries to db"
    duration_from_last_update = 0
  end
end
