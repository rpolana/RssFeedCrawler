require 'active_record'
#require 'database_configuration'
require 'timeout'
require 'nokogiri'
require 'open-uri'


MEDIA_UPDATE_PERIOD_IN_HOURS = 24
SEARCH_TIMEOUT_IN_SECONDS = 60

class RssFeed < ActiveRecord::Base
  def self.initialize_feeds(rss_feeds_filename)
    feeds_file = File.open(rss_feeds_filename, "r");
    if feeds_file
      puts "Reading rss feeds from " + rss_feeds_filename
      new_entry_count = 0
      feeds_file.each_line do | line |
        if (line[0] == '#') or (line.length <= 1)
          next # ignore comments and empty lines
        end
        line_fields = line.split(" ")
        if (line_fields.size >=2)
          link = line_fields[0]
          link_length = link.size
          unless (link_length == 0) or (exists? :link => link)
            title = line[(link_length+1)..-2]
            create!(
              :link => link,
              :title => title
            )
            new_entry_count += 1
            puts "Added feed #{new_entry_count}: link <#{link}> with title <#{title}>"
          end
        end
      end
      puts "Added #{new_entry_count} feeds total"
    end
  end
end

class PodcastFeed < ActiveRecord::Base
  def self.initialize_feeds(rss_feeds_filename)
    feeds_file = File.open(rss_feeds_filename, "r");
    if feeds_file
      puts "Reading podcast feeds from " + rss_feeds_filename
      new_entry_count = 0
      feeds_file.each_line do | line |
        if (line[0] == '#') or (line.length <= 1)
          next # ignore comments and empty lines
        end
        line_fields = line.split(" ")
        if (line_fields.size >=2)
          link = line_fields[0]
          link_length = link.size
          unless (link_length == 0) or (exists? :link => link)
            title = line[(link_length+1)..-2]
            create!(
              :link => link,
              :title => title
            )
            new_entry_count += 1
            puts "Added feed #{new_entry_count}: link <#{link}> with title <#{title}>"
          end
        end
      end
      puts "Added #{new_entry_count} feeds total"
    end
  end
end

ActiveRecord::Base.establish_connection(YAML::load(File.open('db/config/database.yml')))
RssFeed.initialize_feeds('Stemlete/rss_feeds.txt')
PodcastFeed.initialize_feeds('Stemlete/podcast_feeds.txt')
